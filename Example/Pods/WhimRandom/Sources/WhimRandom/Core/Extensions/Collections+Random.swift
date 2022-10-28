// MARK: - Dictionary

extension Dictionary: Random where Key: Random, Value: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> [Key: Value] {
        return random(ofLength: 3, using: &generator)
    }
}

extension Dictionary where Key: Random, Value: Random {
    public static func random<G: RandomNumberGenerator>(ofLength length: UInt, using generator: inout G) -> [Key: Value] {
        return (0 ..< length).reduce(into: [:]) { (acc, _) in
            acc[Key.random(using: &generator)] = Value.random(using: &generator)
        }
    }

    public static func random<G: RandomNumberGenerator>(ofLength range: Range<UInt>, using generator: inout G) -> [Key: Value] {
        random(ofLength: .random(in: range, using: &generator), using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(ofLength range: ClosedRange<UInt>, using generator: inout G) -> [Key: Value] {
        random(ofLength: .random(in: range, using: &generator), using: &generator)
    }
}

extension Dictionary where Key: Hashable & Strideable, Value: Hashable & Strideable {
    public static func random<G: RandomNumberGenerator>(ofLength length: UInt, inKeys keys: [Key], inValues values: [Value], using generator: inout G) -> [Key: Value] {
        precondition(!keys.isEmpty, "keys range shouldn't be empty")
        precondition(!values.isEmpty, "values range shouldn't be empty")

        return (0 ..< length).reduce(into: [:]) { (acc, _) in
            acc[keys.randomElement(using: &generator)!] = values.randomElement(using: &generator)!
        }
    }
}

// MARK: - Set

extension Set: Random where Element: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Set<Element> {
        return random(ofLengthUpTo: 3, using: &generator)
    }
}

extension Set where Element: Random {
    /// Will generate exact number of unique items.
    public static func random<G: RandomNumberGenerator>(ofLength length: UInt, using generator: inout G) -> Set<Element> {
        var buffer = Set()
        while buffer.count != length {
            buffer.insert(Element.random(using: &generator))
        }
        return buffer
    }

    /// Will try to generate given number of unique items, but it doesn't guarantee that there will be exact same number of them.
    /// Can be helpful when auto-generating Set of enum cases.
    /// And if there're less enum cases than expected length, it won't fall into infinite loop.
    public static func random<G: RandomNumberGenerator>(ofLengthUpTo length: UInt, using generator: inout G) -> Set<Element> {
        return (0 ..< length).reduce(into: []) { (acc, _) in
            acc.insert(Element.random(using: &generator))
        }
    }
}

// MARK: - Array

extension Array: Random where Element: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> [Element] {
        return random(ofLength: 3, using: &generator)
    }
}

extension Array where Element: Random {
    public static func random<G: RandomNumberGenerator>(ofLength length: UInt, using generator: inout G) -> [Element] {
        return (0 ..< length).map { _ in Element.random(using: &generator) }
    }

    public static func random<G: RandomNumberGenerator>(ofLength range: Range<UInt>, using generator: inout G) -> [Element] {
        random(ofLength: .random(in: range, using: &generator), using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(ofLength range: ClosedRange<UInt>, using generator: inout G) -> [Element] {
        random(ofLength: .random(in: range, using: &generator), using: &generator)
    }
}

extension Array {
    public static func random<G: RandomNumberGenerator>(ofLength length: UInt, from array: [Element], using generator: inout G) -> [Element] {
        guard !array.isEmpty else { return [] }

        return (0 ..< length).map { _ in array.randomElement(using: &generator)! }
    }

    public static func random<G: RandomNumberGenerator>(ofLength range: Range<UInt>, from array: [Element], using generator: inout G) -> [Element] {
        random(ofLength: .random(in: range, using: &generator), from: array, using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(ofLength range: ClosedRange<UInt>, from array: [Element], using generator: inout G) -> [Element] {
        random(ofLength: .random(in: range, using: &generator), from: array, using: &generator)
    }
}

// MARK: - Range

extension Range: Random where Bound: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Range<Bound> {
        let lowerBound = Bound.random(using: &generator)
        var upperBound = Bound.random(using: &generator)
        while upperBound <= lowerBound {
            upperBound = Bound.random(using: &generator)
        }
        return Range(uncheckedBounds: (lower: lowerBound, upper: upperBound))
    }
}

extension ClosedRange: Random where Bound: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> ClosedRange<Bound> {
        let lowerBound = Bound.random(using: &generator)
        var upperBound = Bound.random(using: &generator)
        while upperBound <= lowerBound {
            upperBound = Bound.random(using: &generator)
        }
        return ClosedRange(uncheckedBounds: (lower: lowerBound, upper: upperBound))
    }
}
