//
//  UIFont+Whim.swift
//  whim-ios
//
//  Created by Do Duc on 21/06/16.
//  Copyright © 2016 maas. All rights reserved.
//

import UIKit

public extension UIFont {
    class func whimFontRegular(_ size: CGFloat) -> UIFont {
        .systemFont(ofSize: size)
    }

    class func whimFontMedium(_ size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .medium)
    }

    class func whimFontSemiBold(_ size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .semibold)
    }

    class func whimFontBold(_ size: CGFloat) -> UIFont {
        .boldSystemFont(ofSize: size)
    }
}

public struct Font {
    public static let regular20 = UIFont.whimFontRegular(20)
    public static let medium15 = UIFont.whimFontMedium(15)
    public static let medium16 = UIFont.whimFontMedium(16)
    public static let medium18 = UIFont.whimFontMedium(18)
    public static let bold18 = UIFont.whimFontBold(18)
    public static let bold20 = UIFont.whimFontBold(20)
    public static let bold22 = UIFont.whimFontBold(22)
}
