import UIKit
import CoreLocation
import RxSwift
import RxRelay

/// Marker on the map.
///
/// Describes both, data and rendering properties.
/// Object uniqueness is defined by its `ObjectIdentifier` to keep consistency with MapKit and GMS.
///
/// # Correspondence
///   - MKAnnotation + MKAnnotationView
///   - GSMMarker
open class MapMarker {
    // sourcery: Random
    /// Marker content as image or custom view with center offset.
    public struct Content: Equatable {
        /// Modify icon by keeping current center-offset.
        public var icon: MapMarker.Icon?
        /// Modify center-offset by keeping current icon.
        public var centerOffset: CGPoint

        public init(icon: MapMarker.Icon?, centerOffset: CGPoint = .zero) {
            self.icon = icon
            self.centerOffset = centerOffset
        }

        /// Update both icon and center-offset at once.
        public mutating func setIcon(_ icon: MapMarker.Icon?, centerOffset: CGPoint) {
            self.icon = icon
            self.centerOffset = centerOffset
        }
    }

    // sourcery: Random
    /// Icon, represented as an image, or as a totally custom view.
    ///
    /// - Remark: We can also add an option with url + placeholder if needed
    public enum Icon: Equatable {
        case image(CustomAnimatable<UIImage>), view(UIView)
    }

    /// Animatable observable coordinate.
    ///
    /// Changing value, immediately renders it on the map if belongs to active layer.
    ///
    /// # Correspondence:
    ///   - MKAnnotation: coordinate
    ///   - GMSMarker: position + layer.latitude/.longitude
    public final let coordinate: BehaviorRelay<CustomAnimatable<CLLocationCoordinate2D>>

    /// Observable content.
    ///
    /// Changing value, immediately renders it on the map if belongs to active layer.
    ///
    /// Content will be rendered right above coordinate by default (with zero center offset).
    /// Center offset will be applied correspondingly.
    ///
    /// - Note:
    ///   If you want to achieve behavior similar to inheriting MKAnnotationView,
    ///   simply create `view` content with any custom `UIView` subview,
    ///   and override `didMoveToSuperview` and/or `removeFromSuperview` to handle rendering.
    ///
    /// # Correspondence
    ///   - MKAnnotationView: image + centerOffset
    ///   - GMSMarker: icon/iconView + groundAnchor
    public final let content: BehaviorRelay<Content>
    /// Animatable observable alpha level.
    ///
    /// Changing value, immediately renders it on the map if belongs to active layer.
    ///
    /// # Correspondence
    ///   - MKAnnotationView: alpha
    ///   - GMSMarker: opacity + (layer.opacity with CAAnimation)
    public final let alpha: BehaviorRelay<CustomAnimatable<CGFloat>>
    /// Changes when user interacts with marker. Read-only observable propery.
    ///
    /// # Correspondence
    ///   - MKAnnotationView: isSelected
    ///   - MKMapView: selectedAnnotations
    ///   - GMSMapView: selectedMarker
    public final let isSelected: ObservableProperty<Bool>
    private let _isSelected: BehaviorRelay<Bool>
    /// Indicates whether the marker animates when being rendered on the map.
    ///
    /// # Correspondence
    ///   - MKMarkerAnnotationView: animatesWhenAdded
    ///   - GMSMarker: appearAnimation
    public final let animatesWhenAdded: Bool
    /// An identifier that determines whether the marker participates in clustering.
    ///
    /// # Correspondence
    ///   - MKAnnotationView: clusteringIdentifier
    public final let clusteringIdentifier: MapClusteringIdentifier?

    /// Additional data without needing to subclass. Not used by map at all.
    ///
    /// # Correspondence
    ///   - GMSMarker: userData
    public final var userData: Any?

    public init(
        coordinate: CLLocationCoordinate2D,
        icon: Icon? = nil,
        centerOffset: CGPoint = .zero,
        alpha: CGFloat = 1,
        animatesWhenAdded: Bool = false,
        clusteringIdentifier: String? = nil,
        userData: Any? = .none
    ) {
        self.coordinate = BehaviorRelay(value: CustomAnimatable(coordinate))
        self.content = BehaviorRelay(value: Content(icon: icon, centerOffset: centerOffset))
        self.alpha = BehaviorRelay(value: CustomAnimatable(alpha))
        self._isSelected = BehaviorRelay(value: false)
        self.isSelected = ObservableProperty(self._isSelected)
        self.animatesWhenAdded = animatesWhenAdded
        self.clusteringIdentifier = clusteringIdentifier
        self.userData = userData
    }
}

extension MapMarker {
    /// You should not call this method directly!
    /// It's used internally by the map to update marker when user interacts with it.
    func setSelected(_ flag: Bool) {
        _isSelected.accept(flag)
    }
}

extension MapMarker: Equatable, Hashable {
    public static func == (lhs: MapMarker, rhs: MapMarker) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension MapMarker.Icon {
    var image: CustomAnimatable<UIImage>? {
        guard case let .image(value) = self else { return nil }
        return value
    }

    var view: UIView? {
        guard case let .view(value) = self else { return nil }
        return value
    }
}
