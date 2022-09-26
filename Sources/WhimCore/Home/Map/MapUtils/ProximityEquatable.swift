import CoreLocation
import MapKit

protocol ProximityEquatable {
    func isCloseTo(_ other: Self, within delta: Double) -> Bool
}

extension ProximityEquatable {
    static var defaultDelta: Double { 0.000_000_1 }

    func isCloseTo(_ other: Self) -> Bool {
        isCloseTo(other, within: Self.defaultDelta)
    }

    func isNotCloseTo(_ other: Self, within delta: Double) -> Bool {
        !isCloseTo(other, within: delta)
    }

    func isNotCloseTo(_ other: Self) -> Bool {
        isNotCloseTo(other, within: Self.defaultDelta)
    }
}

extension Double: ProximityEquatable {
    func isCloseTo(_ other: Double, within delta: Double) -> Bool {
        return abs(self - other) < delta
    }
}

extension CLLocationCoordinate2D: ProximityEquatable {
    func isCloseTo(_ other: CLLocationCoordinate2D, within delta: Double) -> Bool {
        return latitude.isCloseTo(other.latitude, within: delta)
            && longitude.isCloseTo(other.longitude, within: delta)
    }
}

extension MapCoordinateSpan: ProximityEquatable {
    func isCloseTo(_ other: MapCoordinateSpan, within delta: Double) -> Bool {
        return latitudeDelta.isCloseTo(other.latitudeDelta, within: delta)
            && longitudeDelta.isCloseTo(other.longitudeDelta, within: delta)
    }
}
