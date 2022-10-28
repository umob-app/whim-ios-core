// MARK: - String

extension String: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> String {
        var result = UnicodeScalarView()
        for _ in 0 ..< 10 {
            result.append(UnicodeScalar.random(using: &generator))
        }
        return String(result)
    }
}

extension String {
    public static func random<G: RandomNumberGenerator>(ofLength length: UInt, from string: String, using generator: inout G) -> String {
        guard !string.isEmpty else { return "" }

        return (0 ..< length).reduce(into: "") { acc, _ in
            acc.append(string.randomElement(using: &generator)!)
        }
    }

    public static func random<G: RandomNumberGenerator>(ofRange range: Range<UInt>, from string: String, using generator: inout G) -> String {
        let length = UInt(range.randomElement(using: &generator)!)
        return random(ofLength: length, from: string, using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(ofRange range: ClosedRange<UInt>, from string: String, using generator: inout G) -> String {
        let length = UInt(range.randomElement(using: &generator)!)
        return random(ofLength: length, from: string, using: &generator)
    }
}

// MARK: - Character

extension Character: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Character {
        return Character(UnicodeScalar.random(using: &generator))
    }
}

extension Character {
    // Can't convert Character into UnicodeScalar or into UInt, thus constraining it with UnicodeScalar range
    public static func random<G: RandomNumberGenerator>(in closedRange: ClosedRange<UnicodeScalar>, using generator: inout G) -> Character {
        return Character(UnicodeScalar.random(in: closedRange, using: &generator))
    }
}

extension Character {
    // Can't convert Character into UnicodeScalar or into UInt, thus constraining it with UnicodeScalar range
    public static func random<G: RandomNumberGenerator>(in range: Range<UnicodeScalar>, using generator: inout G) -> Character {
        return Character(UnicodeScalar.random(in: range, using: &generator))
    }
}

// MARK: - UnicodeScalar

extension UnicodeScalar: Random {
    static let randomRange: ClosedRange<UnicodeScalar> = " " ... "~"

    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> UnicodeScalar {
        return UnicodeScalar.random(in: randomRange, using: &generator)
    }
}

extension UnicodeScalar {
    public static func random<G: RandomNumberGenerator>(in closedRange: ClosedRange<UnicodeScalar>, using generator: inout G) -> UnicodeScalar {
        let newRange = ClosedRange(uncheckedBounds: (lower: closedRange.lowerBound.value, upper: closedRange.upperBound.value))
        let random = UInt32.random(in: newRange, using: &generator)
        return UnicodeScalar(random)!
    }
}

extension UnicodeScalar {
    public static func random<G: RandomNumberGenerator>(in range: Range<UnicodeScalar>, using generator: inout G) -> UnicodeScalar {
        let newRange = Range(uncheckedBounds: (lower: range.lowerBound.value, upper: range.upperBound.value))
        let random = UInt32.random(in: newRange, using: &generator)
        return UnicodeScalar(random)!
    }
}
