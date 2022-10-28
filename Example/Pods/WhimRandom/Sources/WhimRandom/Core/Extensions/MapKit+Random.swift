import MapKit

// MARK: - Rect

extension MKMapRect: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MKMapRect {
        return .random(width: widthRange, height: heightRange, using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(width: ClosedRange<Double>, height: ClosedRange<Double>, using generator: inout G) -> MKMapRect {
        let size = MKMapSize.random(width: width, height: height, using: &generator)
        let maxX = world.width - size.width
        let maxY = world.height - size.height
        return MKMapRect(
            origin: .random(x: world.minX...maxX, y: world.minY...maxY, using: &generator),
            size: size
        )
    }
}

public extension MKMapRect {
    static let xPointRange = world.minX...world.maxX
    static let yPointRange = world.minY...world.maxY

    static let widthRange = 0...world.width
    static let heightRange = 0...world.height
}

// MARK: - Size

extension MKMapSize: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MKMapSize {
        return .random(width: MKMapRect.widthRange, height: MKMapRect.heightRange, using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(width: ClosedRange<Double>, height: ClosedRange<Double>, using generator: inout G) -> MKMapSize {
        return MKMapSize(
            width: .random(in: width, using: &generator),
            height: .random(in: height, using: &generator)
        )
    }
}

// MARK: - Point

extension MKMapPoint: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MKMapPoint {
        return .random(x: MKMapRect.xPointRange, y: MKMapRect.yPointRange, using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(x: ClosedRange<Double>, y: ClosedRange<Double>, using generator: inout G) -> MKMapPoint {
        return MKMapPoint(
            x: .random(in: x, using: &generator),
            y: .random(in: y, using: &generator)
        )
    }
}

// MARK: - Region

extension MKCoordinateRegion: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MKCoordinateRegion {
        return .random(lat: latRange, lon: lonRange, using: &generator)
    }


    public static func random<G: RandomNumberGenerator>(lat: ClosedRange<CLLocationDegrees>, lon: ClosedRange<CLLocationDegrees>, using generator: inout G) -> MKCoordinateRegion {
        return MKCoordinateRegion(center: .random(using: &generator), span: .random(lat: lat, lon: lon, using: &generator))
    }
}

public extension MKCoordinateRegion {
    static let world = MKCoordinateRegion(.world)

    static let latCoordRange = (world.center.latitude - world.span.latitudeDelta / 2)...(world.center.latitude + world.span.latitudeDelta / 2)
    static let lonCoordRange = (world.center.longitude - world.span.longitudeDelta / 2)...(world.center.longitude + world.span.longitudeDelta / 2)

    static let latRange = 0...world.span.latitudeDelta
    static let lonRange = 0...world.span.longitudeDelta
}

extension MKCoordinateSpan: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MKCoordinateSpan {
        return .random(lat: MKCoordinateRegion.latRange, lon: MKCoordinateRegion.lonRange, using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(lat: ClosedRange<CLLocationDegrees>, lon: ClosedRange<CLLocationDegrees>, using generator: inout G) -> MKCoordinateSpan {
        return MKCoordinateSpan(
            latitudeDelta: .random(in: lat, using: &generator),
            longitudeDelta: .random(in: lon, using: &generator)
        )
    }
}
