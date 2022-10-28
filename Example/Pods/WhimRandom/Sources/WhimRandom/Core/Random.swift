// MARK: - Random

public protocol Random {
    static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self
}

public extension Random {
    static func random() -> Self {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }
}

// MARK: - RandomAll

public protocol RandomAll: Random {
    static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [Self]
}

extension RandomAll {
    public static func allRandom() -> [Self] {
        var generator = SystemRandomNumberGenerator()
        return allRandom(using: &generator)
    }
}

extension RandomAll {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        return allRandom(using: &generator).randomElement(using: &generator)!
    }
}

extension RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(where predicate: (Self) -> Bool, using generator: inout G) -> [Self] {
        return allRandom(using: &generator).filter(predicate)
    }

    public static func random<G: RandomNumberGenerator>(where predicate: (Self) -> Bool, using generator: inout G) -> Self? {
        return allRandom(where: predicate, using: &generator).randomElement(using: &generator)
    }

    public static func allRandom<G: RandomNumberGenerator>(except predicate: (Self) -> Bool, using generator: inout G) -> [Self] {
        return allRandom(using: &generator).filter { !predicate($0) }
    }

    public static func random<G: RandomNumberGenerator>(except predicate: (Self) -> Bool, using generator: inout G) -> Self? {
        return allRandom(except: predicate, using: &generator).randomElement(using: &generator)
    }
}

extension RandomAll where Self: Equatable {
    public static func allRandom<G: RandomNumberGenerator>(where item: Self, using generator: inout G) -> [Self] {
        return allRandom(where: { $0 == item }, using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(where item: Self, using generator: inout G) -> Self? {
        return allRandom(where: item, using: &generator).randomElement(using: &generator)
    }

    public static func allRandom<G: RandomNumberGenerator>(except item: Self, using generator: inout G) -> [Self] {
        return allRandom(except: { $0 == item }, using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(except item: Self, using generator: inout G) -> Self? {
        return allRandom(except: item, using: &generator).randomElement(using: &generator)
    }
}

// MARK: - Random Action

public func random<G: RandomNumberGenerator>(_ actions: () -> Void..., using generator: inout G) {
    actions.randomElement(using: &generator)?()
}

public func random<G: RandomNumberGenerator>(_ actions: [() -> Void], using generator: inout G) {
    actions.randomElement(using: &generator)?()
}

public func random(_ actions: () -> Void...) {
    var generator = SystemRandomNumberGenerator()
    random(actions, using: &generator)
}

public func random(_ actions: [() -> Void]) {
    var generator = SystemRandomNumberGenerator()
    random(actions, using: &generator)
}
