//
//  ArrayEquatableExtensions.swift
//  WhimUtils
//
//  Created by Do Duc on 17/06/2019.
//

import Foundation

public enum JoinResult<T : Equatable>: Equatable {
    case valid
    case missing(T)
}

public extension Array where Element: Equatable {
    mutating func remove(element: Element) {
        if let index = self.firstIndex(of: element) {
            remove(at: index)
        }
    }

    mutating func mergeElements(newArray: [Element]) {
        let additionalElements = newArray.filter({ !self.contains($0) })
        self.append(contentsOf: additionalElements)
    }

    mutating func update(with newElement: Element) -> Bool {
        if let index = self.firstIndex(of: newElement) {
            self[index] = newElement
            return true
        }

        return false
    }

    mutating func updateOrAppend(with newElement: Element) {
        if let index = self.firstIndex(of: newElement) {
            self[index] = newElement
        } else {
            self.append(newElement)
        }
    }

    mutating func removeDuplicates() {
        self = filterDuplicates()
    }

    func filterDuplicates() -> [Element] {
        var result = [Element]()
        for value in self {
            if !result.contains(value) {
                result.append(value)
            }
        }
        return result
    }
    
    func filterDuplicate<T:Hashable>(_ keyValue:(Element)->T) -> [Element]
    {
        var uniqueKeys = Set<T>()
        return filter{uniqueKeys.insert(keyValue($0)).inserted}
    }
    
    func filterDuplicate<T>(_ keyValue:(Element)->T) -> [Element]
    {
        return filterDuplicate{"\(keyValue($0))"}
    }
    
    func contains(array: [Element]) -> Bool {
        for item in array {
            if !self.contains(item) { return false }
        }
        return true
    }

    func hasIntersection(array: [Element]) -> Bool {
        for item in array {
            if self.contains(item) {
                return true                
            }
        }
        return false
    }

    // Not using Set to avoid order changing
    func excluded(_ excludes: [Element]) -> [Element] {
        return filter({ !excludes.contains($0) })
    }
    
    /// - Parameter predicate: A closure that takes an element of the sequence
    ///   as its argument and returns a Boolean value that indicates whether
    ///   the passed array represents a match.
    /// - Returns: `true` if the sequence contains a sequence that satisfies
    ///   `predicate`; otherwise, `false`.
    func contains(_ elements: [Element]) -> JoinResult<[Element]> {
        let missing = elements.filter({ !contains($0) })

        guard missing.isEmpty else {
            return .missing(missing)
        }

        return .valid
    }
}
