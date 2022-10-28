// MARK: - FloatingPoint

extension FloatingPoint where Self: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        return Self(UInt.random(using: &generator)) / Self(UInt.max)
    }
}

extension FloatingPoint where Self: Random {
    public static func random<G: RandomNumberGenerator>(fractionPrecision: UInt8, using generator: inout G) -> Self {
        let value = Self(UInt32.random(using: &generator))
        let divider = 10 ^ fractionPrecision
        return value.rounded(.toNearestOrAwayFromZero) / Self(divider)
    }
}

extension Float: Random { }

extension Double: Random { }

// MARK: - Integer

extension FixedWidthInteger where Self: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        return Self.random(in: Self.min...Self.max, using: &generator)
    }
}

// MARK: Int

extension Int: Random { }

extension Int64: Random { }

extension Int32: Random { }

extension Int16: Random { }

extension Int8: Random { }

// MARK: UInt

extension UInt: Random { }

extension UInt64: Random { }

extension UInt32: Random { }

extension UInt16: Random { }

extension UInt8: Random { }

// MARK: - Bool

extension Bool: Random { }
