import WhimRandom
import WhimCore
import OrderedCollections

extension OrderedSet: Random where Element: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> OrderedSet<Element> {
        return random(ofLength: 5, using: &generator)
    }
}

extension OrderedSet where Element: Random {
    public static func random<G: RandomNumberGenerator>(ofLength length: UInt, using generator: inout G) -> OrderedSet<Element> {
        var buffer = OrderedSet()
        while buffer.count != length {
            buffer.append(Element.random(using: &generator))
        }
        return buffer
    }
}
