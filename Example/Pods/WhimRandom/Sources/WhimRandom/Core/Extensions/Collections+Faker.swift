import Foundation

extension Array where Element == String {
    public static func random<G: RandomNumberGenerator>(_ domain: Faker.Domain, ofLength length: UInt, using generator: inout G) -> [Element] {
        return (0 ..< length).map { _ in .random(domain, using: &generator) }
    }

    public static func random<G: RandomNumberGenerator>(_ domain: Faker.Domain, ofLength range: Range<UInt>, using generator: inout G) -> [Element] {
        random(domain, ofLength: .random(in: range, using: &generator), using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(_ domain: Faker.Domain, ofLength range: ClosedRange<UInt>, using generator: inout G) -> [Element] {
        random(domain, ofLength: .random(in: range, using: &generator), using: &generator)
    }
}

extension Set where Element == String {
    /// Will try to generate given number of unique items, but it doesn't guarantee that there will be exact same number of them.
    /// Can be helpful when auto-generating Set of enum cases.
    /// And if there're less enum cases than expected length, it won't fall into infinite loop.
    public static func random<G: RandomNumberGenerator>(_ domain: Faker.Domain, ofLengthUpTo length: UInt, using generator: inout G) -> Set<Element> {
        return (0 ..< length).reduce(into: []) { (acc, _) in
            acc.insert(.random(domain, using: &generator))
        }
    }
}
