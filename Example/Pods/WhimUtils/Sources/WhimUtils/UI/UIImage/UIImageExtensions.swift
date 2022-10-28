//
//  UIImageExtensions.swift
//  WhimUtils
//
//  Created by Do Duc on 02/08/2018.
//

import UIKit
import Accelerate
import ImageIO

/// Extensions to the UIImage class
public extension UIImage {
    /// Provides a shorthand for image width.
    var width: CGFloat {
        return self.size.width
    }
    
    /// Provides a shorthand for image height.
    var height: CGFloat {
        return self.size.height
    }
    
    /// Blur algorithms
    enum BlurAlgorithm {
        case boxConvolve
        case tentConvolve
    }
    
    /**
     Returns a blurred version of the image.
     
     - parameter radius: radius of the blur kernel, in pixels.
     - parameter algorithm: blur algorithm to use. .TentConvolve is faster than .BoxConvolve.
     - returns: the blurred image.
     */
    func blur(radius: Double, algorithm: BlurAlgorithm = .tentConvolve) -> UIImage {
        let imageRect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        
        func createEffectBuffer(_ context: CGContext) -> vImage_Buffer {
            let data = context.data
            let width = vImagePixelCount(context.width)
            let height = vImagePixelCount(context.height)
            let rowBytes = context.bytesPerRow
            
            return vImage_Buffer(data: data, height: height, width: width, rowBytes: rowBytes)
        }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, UIScreen.main.scale)
        let effectInContext = UIGraphicsGetCurrentContext()
        effectInContext?.scaleBy(x: 1.0, y: -1.0)
        effectInContext?.translateBy(x: 0, y: -self.size.height)
        effectInContext?.draw(self.cgImage!, in: imageRect) // this takes time
        var effectInBuffer = createEffectBuffer(effectInContext!)
        
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        let effectOutContext = UIGraphicsGetCurrentContext()
        var effectOutBuffer = createEffectBuffer(effectOutContext!)
        
        let inputRadius = CGFloat(radius) * UIScreen.main.scale
        let f = inputRadius * 3.0 * CGFloat(sqrt(2 * Double.pi))
        var radius = UInt32(floor((f / 4) + 0.5))
        if radius % 2 != 1 {
            radius += 1 // force radius to be odd
        }
        
        let imageEdgeExtendFlags = vImage_Flags(kvImageEdgeExtend)
        
        if algorithm == .boxConvolve {
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
            vImageBoxConvolve_ARGB8888(&effectOutBuffer, &effectInBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
        } else {
            vImageTentConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, nil, 0, 0, radius, radius, nil, imageEdgeExtendFlags)
        }
        
        let effectImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        UIGraphicsEndImageContext()
        
        return effectImage!
    }
}
