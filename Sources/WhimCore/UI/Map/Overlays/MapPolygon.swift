import UIKit
import CoreLocation
import RxSwift
import RxRelay

/// A closed polygon shape.
///
/// Describes both, data and rendering properties.
///
/// # Correspondence
///   - MKPolygon + MKPolygonRenderer
///   - GMSPolygon
public final class MapPolygon {
    /// # Correspondence
    ///   - MKPolygon: title
    ///   - GMSPolygon: title
    public let title: String?
    /// # Correspondence
    ///   - MKPolygon: getCoordinates
    ///   - GMSPolygon: path
    public let coordinates: [CLLocationCoordinate2D]
    /// # Correspondence
    ///   - MKPolygon: interiorPolygons
    ///   - GMSPolygon: holes
    public let interiorPolygons: [MapPolygon]?

    /// # Correspondence
    ///   - MKPolygonRenderer: lineWidth
    ///   - GMSPolygon: strokeWidth
    public let lineWidth: CGFloat
    /// # Correspondence
    ///   - MKPolygonRenderer: strokeColor
    ///   - GMSPolygon: strokeColor
    public let strokeColor: UIColor?
    /// # Correspondence
    ///   - MKPolygonRenderer: fillColor
    ///   - GMSPolygon: fillColor
    public let fillColor: UIColor?
    /// # Correspondence
    ///   - MKPolygonRenderer: lineDashPattern
    ///   - GMSPolygon: spans
    public let lineDashPattern: [NSNumber]?
    /// # Correspondence
    ///   - MKPolygonRenderer: lineCap
    public let lineCap: CGLineCap
    /// # Correspondence
    ///   - MKPolygonRenderer: lineJoin
    public let lineJoin: CGLineJoin
    /// # Correspondence
    ///   - MKPolygonRenderer: alpha
    ///   - GMSPolygon: opacity
    public let alpha: CGFloat

    /// Additional data without needing to subclass. Not used by map at all.
    ///
    /// # Correspondence
    ///   - GMSPolygon: userData
    public let userData: Any?

    /// Observe events as they happen.
    ///
    /// # Correspondence
    ///   - MKMapViewDelegate
    ///   - GMSMapViewDelegate
    public var events: Observable<MapOverlay.Event> { _events.asObservable() }
    private let _events = PublishRelay<MapOverlay.Event>()

    public init(
        title: String? = nil,
        coordinates: [CLLocationCoordinate2D],
        interiorPolygons: [MapPolygon]? = nil,
        lineWidth: CGFloat,
        strokeColor: UIColor? = .blue,
        fillColor: UIColor? = .clear,
        lineDashPattern: [NSNumber]? = nil,
        lineCap: CGLineCap = .round,
        lineJoin: CGLineJoin = .round,
        alpha: CGFloat = 1,
        userData: Any? = .none
    ) {
        self.title = title
        self.coordinates = coordinates
        self.interiorPolygons = interiorPolygons
        self.lineWidth = lineWidth
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.lineDashPattern = lineDashPattern
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.alpha = alpha
        self.userData = userData
    }
}

extension MapPolygon {
    /// You should not call this method directly!
    /// It's used internally by the map to update overlay when user interacts with it.
    func didTap(at coordinate: CLLocationCoordinate2D) {
        _events.accept(.didTap(coordinate))
    }
}

extension MapPolygon: Equatable, Hashable {
    public static func == (lhs: MapPolygon, rhs: MapPolygon) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
