//
//  UIScreenExtensions.swift
//  whim-ios
//
//  Created by Do Duc on 21/02/2017.
//  Copyright © 2017 maas. All rights reserved.
//

import UIKit

public enum PhoneScreen: Equatable {
    case phone4
    case phone5
    case phone6
    case phone6p
    case other
}

public extension UIScreen {
    var type: PhoneScreen {
        let idiom = UIScreen.main.traitCollection.userInterfaceIdiom
        
        switch idiom {
        case .phone:
            switch CGFloat.screenWidth {
            case 0...320:
                switch CGFloat.screenHeight {
                case 0...480:
                    return .phone4
                default:
                    return .phone5
                }
            case 321...375:
                return .phone6
            default:
                return .phone6p
            }
            
        default:
            return .other
        }
    }
    
    var isLargeScreen: Bool {
        return type == .phone6 || type == .phone6p
    }
}
