import MapKit

// sourcery: Random
public enum AreaRegion: Hashable {
    case circular(CircularRegion)
    case rectangular(RectangularRegion)

    public var center: CLLocationCoordinate2D {
        switch self {
        case let .circular(region):
            return region.center
        case let .rectangular(region):
            return region.region.center
        }
    }

    public var boundingRect: MKCoordinateRegion {
        switch self {
        case let .circular(region):
            return MKCoordinateRegion(center: region.center, latitudinalMeters: region.radius * 2, longitudinalMeters: region.radius * 2)
        case let .rectangular(region):
            return region.region
        }
    }

    public func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        switch self {
        case let .circular(region):
            return region.contains(coordinate)
        case let .rectangular(region):
            return region.contains(coordinate)
        }
    }
}

// sourcery: Random
public struct RectangularRegion: Hashable {
    public let region: MKCoordinateRegion

    // computed properties that are stored here to simplify `contains` calculations
    public let wLon: CLLocationDegrees
    public let eLon: CLLocationDegrees
    public let nLat: CLLocationDegrees
    public let sLat: CLLocationDegrees

    public init(center: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        self.init(region: MKCoordinateRegion(center: center, span: span))
    }

    public init(region: MKCoordinateRegion) {
        self.region = region

        self.wLon = region.wLon
        self.eLon = region.eLon
        self.nLat = region.nLat
        self.sLat = region.sLat
    }

    public func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude < nLat && coordinate.latitude > sLat
            && coordinate.longitude < eLon && coordinate.longitude > wLon
    }

    public static func == (lhs: RectangularRegion, rhs: RectangularRegion) -> Bool {
        return lhs.region == rhs.region
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(region)
    }
}

// sourcery: Random
public struct CircularRegion: Hashable {
    public let center: CLLocationCoordinate2D
    public let radius: CLLocationDistance

    // computed property that is stored here to simplify `contains` calculations
    public let span: MKCoordinateSpan

    public init(center: CLLocationCoordinate2D, radius: CLLocationDistance) {
        self.center = center
        self.radius = radius
        self.span = MKCoordinateRegion(center: center, latitudinalMeters: radius * 2, longitudinalMeters: radius * 2).span
    }

    public func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let (major, minor) = span.longitudeDelta >= span.latitudeDelta
            ? (span.longitudeDelta, span.latitudeDelta)
            : (span.latitudeDelta, span.longitudeDelta)
        // using ellipse equation here
        // because a region that looks like a circle on mercator projection is actually an ellipse when measured in degrees
        return pow(coordinate.longitude - center.longitude, 2) / pow(major / 2, 2)
            + pow(coordinate.latitude - center.latitude, 2) / pow(minor / 2, 2)
            <= 1
    }

    public static func == (lhs: CircularRegion, rhs: CircularRegion) -> Bool {
        return lhs.center == rhs.center
            && lhs.radius == rhs.radius
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(center)
        hasher.combine(radius)
    }
}
