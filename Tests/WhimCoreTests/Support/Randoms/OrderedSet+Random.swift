import WhimRandom
import WhimCore

extension OrderedSet: Random where E: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> OrderedSet<Element> {
        return random(ofLength: 5, using: &generator)
    }
}

extension OrderedSet where E: Random {
    public static func random<G: RandomNumberGenerator>(ofLength length: UInt, using generator: inout G) -> OrderedSet<Element> {
        var buffer = OrderedSet()
        while buffer.count != length {
            buffer.append(Element.random(using: &generator))
        }
        return buffer
    }
}
