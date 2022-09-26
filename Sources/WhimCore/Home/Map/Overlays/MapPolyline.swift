import UIKit
import CoreLocation
import RxSwift
import RxRelay

/// A shape consisting of one or more connected line segments.
///
/// Describes both, data and rendering properties.
/// Object uniqueness is defined by its `ObjectIdentifier` to keep consistency with MapKit and GMS.
///
/// # Correspondence
///   - MKPolyline + MKPolylineRenderer
///   - GMSPolyline
public final class MapPolyline {
    /// # Correspondence
    ///   - MKPolyline: getCoordinates
    ///   - GMSPolyline: path
    public let coordinates: [CLLocationCoordinate2D]

    /// # Correspondence
    ///   - MKPolylineRenderer: lineWidth
    ///   - GMSPolyline: strokeWidth
    public let lineWidth: CGFloat
    /// # Correspondence
    ///   - MKPolylineRenderer: strokeColor
    ///   - GMSPolyline: strokeColor
    public let strokeColor: UIColor?
    /// # Correspondence
    ///   - MKPolylineRenderer: lineDashPattern
    ///   - GMSPolyline: spans
    public let lineDashPattern: [NSNumber]?
    /// # Correspondence
    ///   - MKPolylineRenderer: lineCap
    public let lineCap: CGLineCap
    /// # Correspondence
    ///   - MKPolylineRenderer: lineJoin
    public let lineJoin: CGLineJoin
    /// # Correspondence
    ///   - MKPolylineRenderer: alpha
    ///   - GMSPolyline: opacity
    public let alpha: CGFloat

    /// Additional data without needing to subclass. Not used by map at all.
    ///
    /// # Correspondence
    ///   - GMSPolyline: userData
    public let userData: Any?

    /// Observe events as they happen.
    ///
    /// # Correspondence
    ///   - MKMapViewDelegate
    ///   - GMSMapViewDelegate
    public var events: Observable<MapOverlay.Event> { _events.asObservable() }
    private let _events = PublishRelay<MapOverlay.Event>()

    public init(
        coordinates: [CLLocationCoordinate2D],
        lineWidth: CGFloat,
        strokeColor: UIColor? = .blue,
        lineDashPattern: [NSNumber]? = nil,
        lineCap: CGLineCap = .round,
        lineJoin: CGLineJoin = .round,
        alpha: CGFloat = 1,
        userData: Any? = .none
    ) {
        self.coordinates = coordinates
        self.lineWidth = lineWidth
        self.strokeColor = strokeColor
        self.lineDashPattern = lineDashPattern
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.alpha = alpha
        self.userData = userData
    }
}

extension MapPolyline {
    /// You should not call this method directly!
    /// It's used internally by the map to update overlay when user interacts with it.
    func didTap(at coordinate: CLLocationCoordinate2D) {
        _events.accept(.didTap(coordinate))
    }
}

extension MapPolyline: Equatable, Hashable {
    public static func == (lhs: MapPolyline, rhs: MapPolyline) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
