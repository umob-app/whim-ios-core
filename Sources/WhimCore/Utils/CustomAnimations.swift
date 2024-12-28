import UIKit

public final class WhimCustomAnimations {
    
    static func whimSpinAnimation() -> CAKeyframeAnimation {
        let duration: CFTimeInterval = 3
        let timingFunction = CAMediaTimingFunction(controlPoints: 0.09, 0.57, 0.49, 0.9)
        
        // Animation
        let animation = CAKeyframeAnimation(keyPath: "transform")
        
        animation.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        animation.timingFunctions = [timingFunction, timingFunction, timingFunction, timingFunction]
        animation.values = [
            NSValue(caTransform3D: CATransform3DConcat(WhimCustomAnimations.createRotateXTransform(angle: 0), WhimCustomAnimations.createRotateYTransform(angle: 0))),
            NSValue(caTransform3D: CATransform3DConcat(WhimCustomAnimations.createRotateXTransform(angle: CGFloat(Double.pi)), WhimCustomAnimations.createRotateYTransform(angle: 0))),
            NSValue(caTransform3D: CATransform3DConcat(WhimCustomAnimations.createRotateXTransform(angle: CGFloat(Double.pi)), WhimCustomAnimations.createRotateYTransform(angle: CGFloat(Double.pi)))),
            NSValue(caTransform3D: CATransform3DConcat(WhimCustomAnimations.createRotateXTransform(angle: 0), WhimCustomAnimations.createRotateYTransform(angle: CGFloat(Double.pi)))),
            NSValue(caTransform3D: CATransform3DConcat(WhimCustomAnimations.createRotateXTransform(angle: 0), WhimCustomAnimations.createRotateYTransform(angle: 0)))
        ]
        animation.duration = duration
        animation.repeatCount = HUGE
        animation.isRemovedOnCompletion = false
        
        return animation
    }
    
    static func createRotateXTransform(angle: CGFloat) -> CATransform3D {
        var transform = CATransform3DMakeRotation(angle, 1, 0, 0)
        
        transform.m34 = CGFloat(-1) / 100
        
        return transform
    }
    
    static func createRotateYTransform(angle: CGFloat) -> CATransform3D {
        var transform = CATransform3DMakeRotation(angle, 0, 1, 0)
        
        transform.m34 = CGFloat(-1) / 100
        
        return transform
    }
}
