import UIKit                                        
import CoreLocation
import RxSwift
import RxRelay

/// A circular overlay with a configurable radius and centered on a specific geographic coordinate.
///
/// Describes both, data and rendering properties.
/// Object uniqueness is defined by its `ObjectIdentifier` to keep consistency with MapKit and GMS.
///
/// # Correspondence
///   - MKCircle + MKCircleRenderer
///   - GMSCircle
public final class MapCircle {
    /// # Correspondence
    ///   - MKCircle: coordinate
    ///   - GMSCircle: position
    public let coordinate: CLLocationCoordinate2D
    /// # Correspondence
    ///   - MKCircle: radius
    ///   - GMSCircle: radius
    public let radius: CLLocationDistance

    /// # Correspondence
    ///   - MKCircleRenderer: lineWidth
    ///   - GMSCircle: strokeWidth
    public let lineWidth: CGFloat
    /// # Correspondence
    ///   - MKCircleRenderer: strokeColor
    ///   - GMSCircle: strokeColor
    public let strokeColor: UIColor?
    /// # Correspondence
    ///   - MKCircleRenderer: fillColor
    ///   - GMSCircle: fillColor
    public let fillColor: UIColor?
    /// # Correspondence
    ///   - MKCircleRenderer: lineDashPattern
    ///   - GMSCircle: spans
    public let lineDashPattern: [NSNumber]?
    /// # Correspondence
    ///   - MKCircleRenderer: alpha
    ///   - GMSCircle: opacity
    public let alpha: CGFloat

    /// Additional data without needing to subclass. Not used by map at all.
    ///
    /// # Correspondence
    ///   - GMSCircle: userData
    public let userData: Any?

    /// Observe events as they happen.
    ///
    /// # Correspondence
    ///   - MKMapViewDelegate
    ///   - GMSMapViewDelegate
    public var events: Observable<MapOverlay.Event> { _events.asObservable() }
    private let _events = PublishRelay<MapOverlay.Event>()

    public init(
        coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        lineWidth: CGFloat,
        strokeColor: UIColor? = .blue,
        fillColor: UIColor? = .clear,
        lineDashPattern: [NSNumber]? = nil,
        alpha: CGFloat = 1,
        userData: Any? = .none
    ) {
        self.coordinate = coordinate
        self.radius = radius
        self.lineWidth = lineWidth
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.lineDashPattern = lineDashPattern
        self.alpha = alpha
        self.userData = userData
    }
}

extension MapCircle {
    /// You should not call this method directly!
    /// It's used internally by the map to update overlay when user interacts with it.
    func didTap(at coordinate: CLLocationCoordinate2D) {
        _events.accept(.didTap(coordinate))
    }
}

extension MapCircle: Equatable, Hashable {
    public static func == (lhs: MapCircle, rhs: MapCircle) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
