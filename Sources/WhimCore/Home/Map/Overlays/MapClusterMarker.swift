import CoreLocation
import CoreGraphics
import RxSwift
import RxRelay

/// Cluster of markers on the map.
///
/// Describes both, data and rendering properties.
/// Object uniqueness is defined by its `ObjectIdentifier` to keep consistency with MapKit and GMS.
///
/// # Correspondence
///   - MKClusterAnnotation + MKAnnotationView
///   - GMSMarker + GMUCluster + GMUClusterRenderer + GMUClusterIconGenerator
open class MapClusterMarker {
    public enum Event {
        case didTap
    }

    /// # Correspondece:
    /// - MKClusterAnnotation: memberAnnotations + coordinate
    /// - GMUCluster: items + position
    public let cluster: MapCluster
    /// Animatable observable coordinate.
    ///
    /// Changing value, immediately renders it on the map if belongs to active layer.
    ///
    /// - Note:
    ///   Changing this value doesn't affect original `cluster.coordinate`.
    ///   This value only affects where it's rendered on the map.
    ///
    /// # Correspondence:
    ///   - MKAnnotation: coordinate
    ///   - GMSMarker: position + layer.latitude/.longitude
    public let coordinate: BehaviorRelay<CustomAnimatable<CLLocationCoordinate2D>>
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
    public let content: BehaviorRelay<MapMarker.Content>
    /// Animatable observable alpha level.
    ///
    /// Changing value, immediately renders it on the map if belongs to active layer.
    ///
    /// # Correspondence
    ///   - MKAnnotationView: alpha
    ///   - GMSMarker: opacity + (layer.opacity with CAAnimation)
    public let alpha: BehaviorRelay<CustomAnimatable<CGFloat>>

    /// Additional data without needing to subclass. Not used by map at all.
    ///
    /// # Correspondence
    ///   - GMSMarker: userData
    public var userData: Any?

    /// Observe events as they happen.
    ///
    /// # Correspondence
    ///   - MKMapViewDelegate
    ///   - GMSMapViewDelegate
    public var events: Observable<Event> { _events.asObservable() }
    private let _events = PublishRelay<Event>()

    public init(
        cluster: MapCluster,
        icon: MapMarker.Icon? = nil,
        centerOffset: CGPoint = .zero,
        alpha: CGFloat = 1,
        deselectWhenSelected: Bool = true,
        userData: Any? = .none
    ) {
        self.cluster = cluster
        self.coordinate = BehaviorRelay(value: CustomAnimatable(cluster.coordinate))
        self.content = BehaviorRelay(value: MapMarker.Content(icon: icon, centerOffset: centerOffset))
        self.alpha = BehaviorRelay(value: CustomAnimatable(alpha))
        self.userData = userData
    }
}

extension MapClusterMarker {
    /// You should not call this method directly!
    /// It's used internally by the map to update marker when user interacts with it.
    func didTap() {
        _events.accept(.didTap)
    }
}

extension MapClusterMarker: Equatable, Hashable {
    public static func == (lhs: MapClusterMarker, rhs: MapClusterMarker) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
