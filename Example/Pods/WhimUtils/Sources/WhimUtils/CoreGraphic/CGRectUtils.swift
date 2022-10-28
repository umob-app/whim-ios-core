//
//  CGRectUtils.swift
//  whim-ios
//
//  Created by Do Duc on 21/05/2017.
//  Copyright © 2017 maas. All rights reserved.
//

import UIKit

public extension CGRect {
    func merge(_ otherRect: CGRect) -> CGRect {
        return CGRect(x: self.origin.x + otherRect.origin.x, y: self.origin.y + otherRect.origin.y, width: self.width + otherRect.width, height: self.height + otherRect.height)
    }
    
    /// Shorthand access to the rect's upper left corner's x coordinate
    var x: CGFloat {
        get {
            return origin.x
        }
        set {
            origin.x = newValue
        }
    }
    
    /// Shorthand access to the rect's upper left corner's y coordinate
    var y: CGFloat {
        get {
            return origin.y
        }
        set {
            origin.y = newValue
        }
    }
}
