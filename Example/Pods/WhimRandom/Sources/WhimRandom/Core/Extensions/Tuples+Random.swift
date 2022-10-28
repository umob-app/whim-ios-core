public func randomTuple<
    A: Random,
    B: Random,
    G: RandomNumberGenerator
>(using generator: inout G) -> (A, B) {
    return (
        .random(using: &generator),
        .random(using: &generator)
    )
}

public func randomTuple<
    A: Random,
    B: Random,
    C: Random,
    G: RandomNumberGenerator
>(using generator: inout G) -> (A, B, C) {
    return (
        .random(using: &generator),
        .random(using: &generator),
        .random(using: &generator)
    )
}

public func randomTuple<
    A: Random,
    B: Random,
    C: Random,
    D: Random,
    G: RandomNumberGenerator
>(using generator: inout G) -> (A, B, C, D) {
    return (
        .random(using: &generator),
        .random(using: &generator),
        .random(using: &generator),
        .random(using: &generator)
    )
}

public func randomTuple<
    A: Random,
    B: Random,
    C: Random,
    D: Random,
    E: Random,
    G: RandomNumberGenerator
>(using generator: inout G) -> (A, B, C, D, E) {
    return (
        .random(using: &generator),
        .random(using: &generator),
        .random(using: &generator),
        .random(using: &generator),
        .random(using: &generator)
    )
}
