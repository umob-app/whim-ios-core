//
//  CALayerExtensions.swift
//  Alamofire
//
//  Created by Dima Osadchy on 09/09/2018.
//

import UIKit

public extension CALayer {
    private static let contentLayerName = "contentLayerName"
    
    func addShadow(radius: CGFloat = 6.0, opacity: Float = 0.1, offset: CGSize = CGSize.zero, color: CGColor = UIColor.black.cgColor) {
        shadowColor = color
        shadowRadius = radius
        shadowOpacity = opacity
        shadowOffset = offset
        masksToBounds = false
        if cornerRadius != 0 {
            addShadowWithRoundedCorners()
        }
    }
    
    func roundCorners(radius: CGFloat, cornerMask: CACornerMask? = nil) {
        self.cornerRadius = radius
        if shadowOpacity != 0 {
            addShadowWithRoundedCorners(cornerMask: cornerMask)
        }
    }
    
    private func addShadowWithRoundedCorners(cornerMask: CACornerMask? = nil) {
        masksToBounds = false
        if let sublayer = sublayers?.first, sublayer.name == CALayer.contentLayerName {
            sublayer.removeFromSuperlayer()
        }
        let contentLayer = CALayer()
        contentLayer.name = CALayer.contentLayerName
        contentLayer.frame = bounds
        contentLayer.cornerRadius = cornerRadius
        if let cornerMask = cornerMask {
            contentLayer.maskedCorners = cornerMask
        }
        contentLayer.masksToBounds = true
        insertSublayer(contentLayer, at: 0)
    }
}
