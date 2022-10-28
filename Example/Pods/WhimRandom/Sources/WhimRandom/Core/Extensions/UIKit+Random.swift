import UIKit

extension UIView.AnimationOptions: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> UIView.AnimationOptions {
        let options: UIView.AnimationOptions = [
            .layoutSubviews, .allowUserInteraction, .beginFromCurrentState, .repeat, .autoreverse, .overrideInheritedDuration,
            .overrideInheritedCurve, .allowAnimatedContent, .showHideTransitionViews, .overrideInheritedOptions
        ].randomElement(using: &generator)!

        let curve: UIView.AnimationOptions = [
            .curveEaseInOut, .curveEaseIn, .curveEaseOut, .curveLinear
        ].randomElement(using: &generator)!

        let transition: UIView.AnimationOptions = [
            .transitionFlipFromLeft, .transitionFlipFromRight, .transitionCurlUp, .transitionCurlDown,
            .transitionCrossDissolve, .transitionFlipFromTop, .transitionFlipFromBottom
        ].randomElement(using: &generator)!

        let frames: UIView.AnimationOptions = [
            .preferredFramesPerSecond60, .preferredFramesPerSecond30
        ].randomElement(using: &generator)!

        return options.union(curve).union(transition).union(frames)
    }
}

extension UIColor: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        return Self(
            red: 255.0 / .random(in: 0.0...255.0, using: &generator),
            green: 255.0 / .random(in: 0.0...255.0, using: &generator),
            blue: 255.0 / .random(in: 0.0...255.0, using: &generator),
            alpha: .random(in: 0.0...1.0, using: &generator)
        )
    }
}

extension UIImage: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        let size = CGSize(width: 1, height: 1)
        return UIGraphicsImageRenderer(size: size).image { context in
            context.cgContext.setFillColor(UIColor.random(using: &generator).cgColor)
            context.fill(.init(origin: .zero, size: size))
        } as! Self
    }
}

extension UIView: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        let view = Self(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.backgroundColor = UIColor.random(using: &generator)
        return view
    }
}

extension UIEdgeInsets: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        return .random(in: CGFloat(0)..<CGFloat(100), using: &generator)
    }

    public static func random<G: RandomNumberGenerator>(in range: Range<CGFloat>, using generator: inout G) -> Self {
        return UIEdgeInsets(
            top: .random(in: range, using: &generator),
            left: .random(in: range, using: &generator),
            bottom: .random(in: range, using: &generator),
            right: .random(in: range, using: &generator)
        )
    }

    public static func random<G: RandomNumberGenerator>(in range: ClosedRange<CGFloat>, using generator: inout G) -> Self {
        return UIEdgeInsets(
            top: .random(in: range, using: &generator),
            left: .random(in: range, using: &generator),
            bottom: .random(in: range, using: &generator),
            right: .random(in: range, using: &generator)
        )
    }
}
