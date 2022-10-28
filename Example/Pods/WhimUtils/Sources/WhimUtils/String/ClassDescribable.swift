//
//  ClassDescribable.swift
//  whim-ios
//
//  Created by Dima Osadchy on 27/04/2018.
//  Copyright © 2018 maas. All rights reserved.
//

import Foundation

public protocol ClassDescribable: AnyObject {}

public extension ClassDescribable {
    static var typeString: String {
        return String(describing: type(of: self as Any)).replacingOccurrences(of: ".Type", with: "")
    }
    
    var typeString: String {
        return String(describing: type(of: self as Any))
    }
}
