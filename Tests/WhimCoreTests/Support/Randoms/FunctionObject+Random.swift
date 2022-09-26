import WhimRandom
import WhimCore

extension FunctionObject: Random where Output: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> FunctionObject {
        let result = Output.random(using: &generator)
        return FunctionObject { _ in result }
    }
}
