import Foundation
import MapKit
import RxSwift
import RxRelay

// MARK: - Annotation Data

internal protocol AppleMapsAnnotationData: Equatable {
    var observableCoordinate: ObservableProperty<CustomAnimatable<CLLocationCoordinate2D>> { get }
    var observableContent: ObservableProperty<MapMarker.Content> { get }
    var observableAlpha: ObservableProperty<CustomAnimatable<CGFloat>> { get }
    var isSelected: ObservableProperty<Bool> { get }
    var animatesWhenAdded: Bool { get }
    var isEnabled: Bool { get }

    func setSelected(_ flag: Bool)
}

// MARK: - Annotation

internal class AppleMapsAnnotation<T: AppleMapsAnnotationData>: NSObject, MKAnnotation {
    public let layerToken: MapLayerToken
    public let data: T

    // It's a dynamic property so that it supports KVO (as required by MapKit) out of the box.
    // Also, coordinate value shouldn't be changed since we don't support dragging feature, so it's ok to not listen to its updates.
    public dynamic var coordinate: CLLocationCoordinate2D

    private let disposeBag = DisposeBag()

    public init(marker: T, layerToken: MapLayerToken) {
        self.layerToken = layerToken
        self.data = marker
        self.coordinate = data.observableCoordinate.value.value

        super.init()

        applyCoordinateNewUpdates()
    }

    private func applyCoordinateNewUpdates() {
        data.observableCoordinate.asObservable()
            // skipping first update, as we've already set coordinate in `init`
            .skip(1)
            .distinctUntilChanged()
            .observe(on:MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] newCoordinate in
                if let animation = newCoordinate.animation {
                    UIView.animate(
                        withDuration: animation.duration,
                        delay: animation.delay,
                        options: animation.options,
                        animations: { self?.coordinate = newCoordinate.value }
                    )
                } else {
                    self?.coordinate = newCoordinate.value
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Annotation View

internal class AppleMapsAnnotationView<T: AppleMapsAnnotationData>: MKAnnotationView {
    override var annotation: MKAnnotation? {
        didSet {
            annotationData = (annotation as? AppleMapsAnnotation)?.data
        }
    }

    var annotationData: T? {
        didSet {
            // if it's the same data, it means that we're already subscribed to its updates and there's no need to re-do it again
            if annotationData != oldValue {
                applyNewMarker()
            }
        }
    }

    private var disposeBag = DisposeBag()

    convenience init(annotation: AppleMapsAnnotation<T>, reuseIdentifier: String?) {
        self.init(annotation: annotation as MKAnnotation?, reuseIdentifier: reuseIdentifier)
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        annotationData?.setSelected(isSelected)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    // This method is called at the same time when `mapView(_:didAdd:)` with annotation views is called.
    //
    // So it's used here to implement google-maps-like pop appear animation,
    // keeping the same behavior as if you'd implement it yourself with mapkit.
    //
    // To implement custom animations of your content, see `MapMarker.Icon.view`:
    // you can insert any custom view you want there and implement all appear and disappear animations
    // by overriding `didMoveToSuperview()` with `superview` available and not, respectively.
    override func prepareForDisplay() {
        super.prepareForDisplay()

        guard annotationData?.animatesWhenAdded == true else {
            return
        }
        layer.removeAllAnimations()
        transform = CGAffineTransform(scaleX: 0, y: 0)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: { [weak self] in
            self?.transform = .identity
        })
    }

    private func applyNewMarker() {
        disposeBag = DisposeBag()

        leftCalloutAccessoryView = nil
        rightCalloutAccessoryView = nil
        detailCalloutAccessoryView = nil

        isDraggable = false
        canShowCallout = false

        applyMarkerUpdates()
    }

    private func applyMarkerUpdates() {
        if let marker = annotationData {
            isEnabled = marker.isEnabled
        }
        applyContentUpdates()
        applyAlphaUpdates()
    }

    // MARK: Content Updates

    private func applyContentUpdates() {
        guard let marker = annotationData else {
            return clearContent()
        }
        marker.observableContent.asObservable()
            .distinctUntilChanged()
            .observe(on:MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] newContent in self?.applyNewMarkerContent(newContent) })
            .disposed(by: disposeBag)
    }

    private func applyNewMarkerContent(_ content: MapMarker.Content) {
        switch content.icon {
        case let .image(img)?:
            if let animation = img.animation {
                // weakifying self here to not prolongue annotation view lifespan when it needs to be removed
                UIView.transition(with: self, duration: animation.duration, options: animation.options, animations: { [weak self] in
                    self?.image = img.value
                }, completion: nil)
            } else {
                image = img.value
            }
            replaceContentView(with: nil)
        case let .view(view)?:
            image = nil
            replaceContentView(with: view)
        case nil:
            clearContent()
        }
        // correcting center offset to place annotation above coordinate (it's centered around coordinate by default),
        // similar to pins and markers in Apple and Google maps
        let offsetAboveCoordinate = CGPoint(x: 0, y: frame.size.height / -2)
        centerOffset = CGPoint(
            x: offsetAboveCoordinate.x + content.centerOffset.x,
            y: offsetAboveCoordinate.y + content.centerOffset.y
        )
    }

    private func clearContent() {
        replaceContentView(with: nil)
        image = nil
    }

    private func replaceContentView(with other: UIView?) {
        let contentViews = subviews
        // if there're many subviews or single subview isn't the same as the other view, remove them
        guard contentViews.count > 1 || contentViews.first != other else { return }
        contentViews.forEach { $0.removeFromSuperview() }
        // after everything's clear, adjust frame with center offset depending on the other view, or its absence
        guard let other = other else {
            return
        }
        frame = other.bounds
        addSubview(other)
    }

    // MARK: Alpha Updates

    private func applyAlphaUpdates() {
        guard let marker = annotationData else {
            return clearAlpha()
        }
        marker.observableAlpha.asObservable()
            .distinctUntilChanged()
            .observe(on:MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] newAlpha in self?.applyNewMarkerAlpha(newAlpha) })
            .disposed(by: disposeBag)
    }

    private func applyNewMarkerAlpha(_ alpha: CustomAnimatable<CGFloat>) {
        if let animation = alpha.animation {
            // weakifying self here to not prolongue annotation view lifespan when it needs to be removed
            UIView.animate(withDuration: animation.duration, delay: animation.delay, options: animation.options, animations: { [weak self] in
                self?.alpha = alpha.value
            })
        } else {
            self.alpha = alpha.value
        }
    }

    private func clearAlpha() {
        layer.removeAllAnimations()
        alpha = 1
    }
}

// MARK: Marker vs Cluster

final class AppleMapsMarkerAnnotation: AppleMapsAnnotation<MapMarker> {}
final class AppleMapsMarkerAnnotationView: AppleMapsAnnotationView<MapMarker> {}

final class AppleMapsClusterAnnotation: AppleMapsAnnotation<MapClusterMarker> {}
final class AppleMapsClusterAnnotationView: AppleMapsAnnotationView<MapClusterMarker> {}

// MARK: - Markers Extensions

extension MapMarker: AppleMapsAnnotationData {
    var observableCoordinate: ObservableProperty<CustomAnimatable<CLLocationCoordinate2D>> {
        return ObservableProperty(coordinate)
    }
    var observableContent: ObservableProperty<MapMarker.Content> {
        return ObservableProperty(content)
    }
    var observableAlpha: ObservableProperty<CustomAnimatable<CGFloat>> {
        return ObservableProperty(alpha)
    }
    var isEnabled: Bool {
        return true
    }
}

extension MapClusterMarker: AppleMapsAnnotationData {
    var observableCoordinate: ObservableProperty<CustomAnimatable<CLLocationCoordinate2D>> {
        return ObservableProperty(coordinate)
    }
    var observableContent: ObservableProperty<MapMarker.Content> {
        return ObservableProperty(content)
    }
    var observableAlpha: ObservableProperty<CustomAnimatable<CGFloat>> {
        return ObservableProperty(alpha)
    }
    var isSelected: ObservableProperty<Bool> {
        return ObservableProperty(false)
    }
    func setSelected(_ flag: Bool) {
        return
    }
    var animatesWhenAdded: Bool {
        return false
    }
    var isEnabled: Bool {
        return false
    }
}
