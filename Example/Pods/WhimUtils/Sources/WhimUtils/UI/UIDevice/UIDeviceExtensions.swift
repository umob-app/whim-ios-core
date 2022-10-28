//
//  UIDeviceExtensions.swift
//  whim-ios
//
//  Created by Martin Conklin on 2017-09-12.
//  Copyright © 2017 maas. All rights reserved.
//

import Foundation
import UIKit

public extension UIDevice {

    /// https://stackoverflow.com/questions/26028918/how-to-determine-the-current-iphone-device-model

    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        switch identifier {
        case "iPod5,1":                                  return "iPod Touch 5"
        case "iPod7,1":                                  return "iPod Touch 6"
            
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":      return "iPhone 4"
        case "iPhone4,1":                                return "iPhone 4s"
        case "iPhone5,1", "iPhone5,2":                   return "iPhone 5"
        case "iPhone5,3", "iPhone5,4":                   return "iPhone 5c"
        case "iPhone6,1", "iPhone6,2":                   return "iPhone 5s"
        case "iPhone7,2":                                return "iPhone 6"
        case "iPhone7,1":                                return "iPhone 6 Plus"
        case "iPhone8,1":                                return "iPhone 6s"
        case "iPhone8,2":                                return "iPhone 6s Plus"
        case "iPhone9,1", "iPhone9,3":                   return "iPhone 7"
        case "iPhone9,2", "iPhone9,4":                   return "iPhone 7 Plus"
        case "iPhone8,4":                                return "iPhone SE"
        case "iPhone10,1", "iPhone10,4":                 return "iPhone 8"
        case "iPhone10,2", "iPhone10,5":                 return "iPhone 8 Plus"
        case "iPhone10,3", "iPhone10,6":                 return "iPhone X"
        case "iPhone11,2":                               return "iPhone XS"
        case "iPhone11,4", "iPhone11,6":                 return "iPhone XS Max"
        case "iPhone11,8":                               return "iPhone XR"
        case "iPhone12,1":                               return "iPhone 11"
        case "iPhone12,3":                               return "iPhone 11 Pro"
        case "iPhone12,5":                               return "iPhone 11 Pro Max"
            
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4": return "iPad 2"
        case "iPad3,1", "iPad3,2", "iPad3,3":            return "iPad 3"
        case "iPad3,4", "iPad3,5", "iPad3,6":            return "iPad 4"
        case "iPad4,1", "iPad4,2", "iPad4,3":            return "iPad Air"
        case "iPad5,3", "iPad5,4":                       return "iPad Air 2"
        case "iPad11,3":                                 return "iPad Air (3rd generation)"
        case "iPad6,11", "iPad6,12":                     return "iPad 5"
        case "iPad7,5", "iPad7,6":                       return "iPad 6"
        case "iPad2,5", "iPad2,6", "iPad2,7":            return "iPad Mini"
        case "iPad4,4", "iPad4,5", "iPad4,6":            return "iPad Mini 2"
        case "iPad4,7", "iPad4,8", "iPad4,9":            return "iPad Mini 3"
        case "iPad5,1", "iPad5,2":                       return "iPad Mini 4"
        case "iPad6,3", "iPad6,4":                       return "iPad Pro (9.7-inch)"
        case "iPad6,7", "iPad6,8":                       return "iPad Pro (12.9-inch)"
        case "iPad7,1", "iPad7,2":                       return "iPad Pro (12.9-inch) (2nd generation)"
        case "iPad7,3", "iPad7,4":                       return "iPad Pro (10.5-inch)"
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4": return "iPad Pro (11-inch)"
        case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": return "iPad Pro (12.9-inch) (3rd generation)"
            
        case "AppleTV5,3":                               return "Apple TV"
        case "AppleTV6,2":                               return "Apple TV 4K"
            
        case "AudioAccessory1,1":                        return "HomePod"
            
        case "i386", "x86_64":                           return "Simulator"
        default:                                         return identifier
        }
    }

    /// 0 for not iPhone
    /// 1+ for iPhone
    /// 999 for iPhone that haven't listed
    var iphoneType: Int {
        guard modelName.contains("iPhone") else {
            return 0
        }

        switch modelName {
        case "iPhone 4": return 1
        case "iPhone 4s": return 2
        case "iPhone 5": return 3
        case "iPhone 5c": return 4
        case "iPhone 5s": return 5
        case "iPhone 6": return 6
        case "iPhone 6 Plus": return 7
        case "iPhone 6s": return 8
        case "iPhone 6s Plus": return 9
        case "iPhone SE": return 10
        case "iPhone 7": return 11
        case "iPhone 7 Plus": return 12
        case "iPhone 8": return 13
        case "iPhone 8 Plus": return 14
        case "iPhone X": return 15
        case "iPhone XR": return 16
        case "iPhone XS": return 17
        case "iPhone XS Max": return 18

        default: return 999
        }
    }

    /// 0 for not iPad
    /// 1+ for iPad
    /// 999 for iPad that haven't listed
    var iPadType: Int {
        guard modelName.contains("iPad") else {
            return 0
        }

        switch modelName {
        case "iPad 2": return 1
        case "iPad 3": return 2
        case "iPad 4": return 3
        case "iPad Air": return 4
        case "iPad Air 2": return 5
        case "iPad 5": return 6
        case "iPad Mini": return 7
        case "iPad Mini 2": return 8
        case "iPad Mini 3": return 9
        case "iPad Mini 4": return 10
        case "iPad Pro 9.7 Inch": return 11
        case "iPad Pro 12.9 Inch": return 12
        case "iPad Pro 12.9 Inch 2. Generation": return 13
        case "iPad Pro 10.5 Inch": return 14
        case "iPad Pro (11-inch)": return 15
        case "iPad Pro (12.9-inch) (3rd generation)": return 16

        default: return 999
        }
    }
}

public enum DisplayType {
    case unknown
    case iphone4
    case iphone5
    case iphone6
    case iphone6plus
    case iphoneX
    
    static let iphone7 = iphone6
    static let iphone7plus = iphone6plus
    
    public var maxLength: CGFloat {
        switch self {
        case .iphone4, .iphone5:
            return 568
        case .iphone6:
            return 667
        case .iphone6plus:
            return 736
        case .iphoneX:
            return 812
        default:
            return 0
        }
    }
    
    public static func < (lhs: DisplayType, rhs: DisplayType) -> Bool {
        return lhs.maxLength < rhs.maxLength
    }
    
    public static func > (lhs: DisplayType, rhs: DisplayType) -> Bool {
        return lhs.maxLength > rhs.maxLength
    }
}

// All credits goes to -----> https://gist.github.com/hfossli/bc93d924649de881ee2882457f14e346
//
public final class Display {
    public class var width: CGFloat { return UIScreen.main.bounds.size.width }
    public class var height: CGFloat { return UIScreen.main.bounds.size.height }
    public class var maxLength: CGFloat { return max(width, height) }
    public class var minLength: CGFloat { return min(width, height) }
    public class var zoomed: Bool { return UIScreen.main.nativeScale >= UIScreen.main.scale }
    public class var retina: Bool { return UIScreen.main.scale >= 2.0 }
    public class var phone: Bool { return UIDevice.current.userInterfaceIdiom == .phone }
    public class var pad: Bool { return UIDevice.current.userInterfaceIdiom == .pad }
    public class var carplay: Bool { return UIDevice.current.userInterfaceIdiom == .carPlay }
    public class var tv: Bool { return UIDevice.current.userInterfaceIdiom == .tv }
    
    public class var type: DisplayType {
        if phone && maxLength < DisplayType.iphone4.maxLength {
            return .iphone4
        } else if phone && maxLength == DisplayType.iphone5.maxLength {
            return .iphone5
        } else if phone && maxLength == DisplayType.iphone6.maxLength {
            return .iphone6
        } else if phone && maxLength == DisplayType.iphone6plus.maxLength {
            return .iphone6plus
        } else if phone && maxLength == DisplayType.iphoneX.maxLength {
            return .iphoneX
        }
        return .unknown
    }
}
