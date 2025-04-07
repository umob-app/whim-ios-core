import WhimRandom
import WhimCore

extension Animatable: Random where T: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Animatable<T> {
        Animatable(.random(using: &generator), animated: .random(using: &generator))
    }

    public static func random(
        _ value: T = .random(using: &R),
        animated: Bool = .random(using: &R)
    ) -> Animatable<T> {
        Animatable(value, animated: animated)
    }
}
