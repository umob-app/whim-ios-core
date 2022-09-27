public extension WhimCore {
    static func zip<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
        return a.flatMap { a in b.map { b in (a, b) } }
    }

    static func zip<A, B, C>(_ a: A?, _ b: B?, _ c: C?) -> (A, B, C)? {
        return zip(a, b).flatMap { a, b in c.map { c in (a, b, c) } }
    }

    static func zip<A, B, C, D>(_ a: A?, _ b: B?, _ c: C?, _ d: D?) -> (A, B, C, D)? {
        return zip(a, b, c).flatMap { a, b, c in d.map { d in (a, b, c, d) } }
    }
}

public extension Optional {
    func filter(by predicate: (Wrapped) -> Bool) -> Optional {
        return flatMap { wrapped in
            predicate(wrapped) ? wrapped : nil
        }
    }
}

public extension Optional {
    var isNil: Bool {
        guard case .none = self else { return false }
        return true
    }

    var isNotNil: Bool {
        return !isNil
    }
}
