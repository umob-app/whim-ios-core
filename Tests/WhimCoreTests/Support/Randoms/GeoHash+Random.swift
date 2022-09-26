import WhimRandom
import WhimCore

extension GeoHash {
    public static func random<G>(using generator: inout G) -> GeoHash.Code where G : RandomNumberGenerator {
        GeoHash.Code.random(ofRange: 1...22, from: "0123456789bcdefghjkmnpqrstuvwxyz", using: &generator)
    }
}
