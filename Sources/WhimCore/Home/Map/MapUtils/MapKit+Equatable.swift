import MapKit

extension MKCoordinateSpan: Hashable {
    public static func == (lhs: MKCoordinateSpan, rhs: MKCoordinateSpan) -> Bool {
        return lhs.latitudeDelta == rhs.latitudeDelta
            && lhs.longitudeDelta == rhs.longitudeDelta
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(longitudeDelta)
        hasher.combine(latitudeDelta)
    }
}

extension MKCoordinateRegion: Hashable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        return lhs.center == rhs.center
            && lhs.span == rhs.span
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(center)
        hasher.combine(span)
    }
}

extension MKMapPoint: Equatable {
    public static func == (lhs: MKMapPoint, rhs: MKMapPoint) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}

extension MKMapSize: Equatable {
    public static func == (lhs: MKMapSize, rhs: MKMapSize) -> Bool {
        return lhs.height == rhs.height && lhs.width == rhs.width
    }
}

extension MKMapRect: Equatable {
    public static func == (lhs: MKMapRect, rhs: MKMapRect) -> Bool {
        return lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
