// MARK: - Optional

extension Optional: RandomAll where Wrapped: Random {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [Wrapped?] {
        return [.none, .some(.random(using: &generator))]
    }
}

public func randomOptional<T, G: RandomNumberGenerator>(_ some: T, using generator: inout G) -> T? {
    return [.none, .some(some)].randomElement(using: &generator)!
}

extension Optional: Random where Wrapped: Random {}

// MARK: - Result

extension Result: Random where Success: Random, Failure: Random {
    public static func random<G>(using generator: inout G) -> Result<Success, Failure> where G : RandomNumberGenerator {
        return allRandom(using: &generator).randomElement(using: &generator)!
    }
}

extension Result: RandomAll where Success: Random, Failure: Random {
    public static func allRandom<G>(using generator: inout G) -> [Result<Success, Failure>] where G : RandomNumberGenerator {
        return [.success(.random(using: &generator)), .failure(.random(using: &generator))]
    }
}
