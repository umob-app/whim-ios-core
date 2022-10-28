import Foundation

// MARK: - URL

extension URL: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> URL {
        return URL(string: "https://picsum.photos/200/300/?image=\(UInt.random(in: 1...1000, using: &generator))")!
    }
}

// MARK: - UUID

extension UUID: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> UUID {
        return UUID(uuid: (
            .random(using: &generator), .random(using: &generator), .random(using: &generator), .random(using: &generator),
            .random(using: &generator), .random(using: &generator), .random(using: &generator), .random(using: &generator),
            .random(using: &generator), .random(using: &generator), .random(using: &generator), .random(using: &generator),
            .random(using: &generator), .random(using: &generator), .random(using: &generator), .random(using: &generator)
        ))
    }
}

// MARK: - Date

extension Date: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Date {
        return random(in: .distantPast ... .distantFuture, using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(in closedRange: ClosedRange<Date>, using generator: inout G) -> Date {
        let lower = closedRange.lowerBound.timeIntervalSinceReferenceDate
        let upper = closedRange.upperBound.timeIntervalSinceReferenceDate
        let range = ClosedRange(uncheckedBounds: (lower, upper))
        let value = TimeInterval.random(in: range, using: &generator)
        return Date(timeIntervalSinceReferenceDate: value)
    }

    public static func randomRange<G: RandomNumberGenerator>(
        in range: ClosedRange<Date> = .distantPast ... .distantFuture,
        using generator: inout G
    ) -> (start: Date, end: Date) {
        let mid = random(in: range, using: &generator)
        return (
            start: random(in: range.lowerBound ... mid, using: &generator),
            end: random(in: mid ... range.upperBound, using: &generator)
        )
    }
}

// MARK: - DispatchTimeInterval

extension DispatchTimeInterval: Random {
    public static func random<G>(using generator: inout G) -> DispatchTimeInterval where G : RandomNumberGenerator {
        allRandom(using: &generator).randomElement(using: &generator)!
    }
}

extension DispatchTimeInterval: RandomAll {
    public static func allRandom<G>(using generator: inout G) -> [DispatchTimeInterval] where G : RandomNumberGenerator {
        return [
            .seconds(.random(in: 0 ... .max, using: &generator)),
            .milliseconds(.random(in: 0 ... .max, using: &generator)),
            .microseconds(.random(in: 0 ... .max, using: &generator)),
            .nanoseconds(.random(in: 0 ... .max, using: &generator)),
            .never
        ]
    }
}

// MARK: - NSNumber

extension NSNumber: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        Self(integerLiteral: .random(using: &generator))
    }
}

// MARK: - NSError

extension NSError: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        Self(domain: .random(ofLength: 10, from: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", using: &generator), code: .random(in: 0...100, using: &generator), userInfo: nil)
    }
}

extension Bundle: Random {
    private class BundleClass {}

    /// It's technically not possible to create random bundle on a whim, because it should be attached to a real object in memory
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        Self(for: BundleClass.self)
    }
}
