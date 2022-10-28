//
//  ArrayComparableExtensions.swift
//  WhimUtils
//
//  Created by Do Duc on 17/06/2019.
//

import Foundation

public extension Array where Element: Comparable {
    func isEqual(_ other: [Element]) -> Bool {
        return self.count == other.count && self.sorted() == other.sorted()
    }

    mutating func updateAndSort(with newElement: Element) {
        self.updateOrAppend(with: newElement)
        self.sort()
    }
}
