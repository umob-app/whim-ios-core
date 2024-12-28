import Foundation

public extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

public extension Collection where Element: Collection {
    var flattened: [Element.Element] {
        return flatMap { $0 }
    }
}

public extension Collection where Element: OptionalType {
    var compacted: [Element.Wrapped] {
        return compactMap { $0.optional }
    }
}

public extension Collection where Element == Bool {
    var filtered: [Element] {
        return filter { $0 }
    }
}

public extension Collection {
    func reduce<Key: Hashable>(by transform: (Element) -> Key) -> [Key: Element] {
        reduce(by: transform, with: { $0 })
    }

    func reduce<Key: Hashable, Value>(by keyTransform: (Element) -> Key, with valueTransform: (Element) -> Value) -> [Key: Value] {
        reduce(by: keyTransform, with: { Optional(valueTransform($0)) })
    }

    func reduce<Key: Hashable, Value>(by keyTransform: (Element) -> Key, with valueTransform: (Element) -> Value?) -> [Key: Value] {
        reduce(into: [:]) { acc, element in
            acc[keyTransform(element)] = valueTransform(element)
        }
    }
}
