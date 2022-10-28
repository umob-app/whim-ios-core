//
//  ArrayHashableExtensions.swift
//  WhimUtils
//
//  Created by Duc Do on 31.8.2022.
//

import Foundation

public extension Array where Element: Hashable {
    func intersection(with array: [Element]) -> [Element] {
        let set1 = Set(array)
        let set2 = Set(self)
        
        return Array(set1.intersection(set2))
    }
}

/// https://stackoverflow.com/questions/31220002/how-to-group-by-the-elements-of-an-array-in-swift
public extension Array {
    func group<T: Hashable>(by key: (Element) -> T) -> [T: [Element]] {
        var categories: [T: [Element]] = [:]
        self.forEach { element in
            let key = key(element)
            if case nil = categories[key]?.append(element) {
                categories[key] = [element]
            }
        }
        return categories
    }
    
    func filterDuplicates<T: Hashable>(map: ((Element) -> (T))) -> [Element] {
        var set = Set<T>() //the unique list kept in a Set for fast retrieval
        var arrayOrdered = [Element]() //keeping the unique list of elements but ordered
        for value in self {
            if !set.contains(map(value)) {
                set.insert(map(value))
                arrayOrdered.append(value)
            }
        }
        
        return arrayOrdered
    }
}
