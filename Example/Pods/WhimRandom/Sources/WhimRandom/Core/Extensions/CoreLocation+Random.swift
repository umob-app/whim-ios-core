import CoreLocation

extension CLLocationCoordinate2D: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(
            latitude: .random(in: 0.0...90.0, using: &generator),
            longitude: .random(in: 0.0...180.0, using: &generator)
        )
    }
}

extension CLLocation: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        let coord = CLLocationCoordinate2D.random(using: &generator)
        return Self(
            latitude: coord.latitude,
            longitude: coord.longitude
        )
    }
}

extension CLHeading: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        return Self()
    }
}

extension CLAuthorizationStatus: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> CLAuthorizationStatus {
        return CLAuthorizationStatus(rawValue: .random(in: 0...4, using: &generator))!
    }
}

extension CLError.Code: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> CLError.Code {
        return CLError.Code(
            rawValue: (CLError.Code.locationUnknown.rawValue...CLError.Code.promptDeclined.rawValue).randomElement(using: &generator)!
        )!
    }
}

extension CLError: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> CLError {
        return CLError(.random(using: &generator))
    }
}
