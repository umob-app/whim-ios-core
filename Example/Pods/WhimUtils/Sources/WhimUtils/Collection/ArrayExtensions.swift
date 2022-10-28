//
//  ArrayExtensions.swift
//  WhimUtils
//
//  Created by Do Duc on 05/09/2018.
//

import Foundation

/// https://stackoverflow.com/questions/31220002/how-to-group-by-the-elements-of-an-array-in-swift
public extension Array {

    func random() -> Element {
        let index = Int(arc4random_uniform(UInt32(self.count)))
        return self[index]
    }    
}
