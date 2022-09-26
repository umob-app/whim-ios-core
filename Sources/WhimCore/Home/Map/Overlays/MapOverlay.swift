import Foundation
import CoreLocation
import RxSwift

// MARK: - Overlay

// sourcery: Random
/// Unifies available overlays in a single construction.
public enum MapOverlay: Hashable {
    public enum Event: Equatable {
        case didTap(CLLocationCoordinate2D)
    }

    case polyline(MapPolyline)
    case polygon(MapPolygon)
    case circle(MapCircle)
}

// MARK: - Helpers

public extension MapOverlay {
    var polyline: MapPolyline? {
        guard case let .polyline(value) = self else { return nil }
        return value
    }

    var polygon: MapPolygon? {
        guard case let .polygon(value) = self else { return nil }
        return value
    }

    var circle: MapCircle? {
        guard case let .circle(value) = self else { return nil }
        return value
    }

    var events: Observable<Event> {
        switch self {
        case let .polyline(polyline): return polyline.events
        case let .polygon(polygon): return polygon.events
        case let .circle(circle): return circle.events
        }
    }
}

extension MapOverlay {
    /// You should not call this method directly!
    /// It's used internally by the map to update overlay when user interacts with it.
    func didTap(at coordinate: CLLocationCoordinate2D) {
        switch self {
        case let .polyline(polyline): polyline.didTap(at: coordinate)
        case let .polygon(polygon): polygon.didTap(at: coordinate)
        case let .circle(circle): circle.didTap(at: coordinate)
        }
    }
}
