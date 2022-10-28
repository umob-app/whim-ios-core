//
//  CGFloatExtensions.swift
//  whim-ios
//
//  Created by Do Duc on 31/10/2016.
//  Copyright © 2016 maas. All rights reserved.
//

import UIKit

public extension CGFloat {
    /// Convert CGFloat to Double
    var doubleValue: Double? {
        return Double(self)
    }
    
    /// Convert degrees value to radians value
    func degreesToRadians() -> CGFloat {
        return CGFloat.pi * self / 180.0
    }
    
    /// Convert radians value to degrees value
    func radiansToDegrees() -> CGFloat {
        return self * 180 / CGFloat.pi
    }
    
    /// Returns a random number in the range of [0, 1] (inclusive).
    static func random() -> CGFloat {
        return CGFloat(arc4random()) / CGFloat(UInt32.max)
    }
}

/// Screen measure
public extension CGFloat {
    /// Quick access to screen width
    static var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }
    
    /// Quick access to screen height
    static var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    /// Ratio of current screen with phone 5 screen using width property, should be using for larger screen than iphone 5 (iphone 4/4s will return 1 due to same width)
    static var screenRatio: CGFloat {
        return UIScreen.main.bounds.width / 320
    }
}
