//
//  Animations.swift
//
//  Adapted from
//  https://www.swiftbysundell.com/articles/building-a-declarative-animation-framework-in-swift-part-1/
//

import UIKit

public extension Animation {
    static func fadeIn(duration: TimeInterval = 0.3, delay: TimeInterval = 0, springDamping: CGFloat = 1, initialSpringVelocity: CGFloat = 0) -> Animation {
        return Animation(duration: duration, delay: delay, springDamping: springDamping, initialSpringVelocity: initialSpringVelocity) { $0.alpha = 1 }
    }

    static func fadeOut(duration: TimeInterval = 0.3, delay: TimeInterval = 0, springDamping: CGFloat = 1, initialSpringVelocity: CGFloat = 0) -> Animation {
        return Animation(duration: duration, delay: delay, springDamping: springDamping, initialSpringVelocity: initialSpringVelocity) { $0.alpha = 0 }
    }

    static func resize(to size: CGSize, duration: TimeInterval = 0.3, delay: TimeInterval = 0, springDamping: CGFloat = 1, initialSpringVelocity: CGFloat = 0) -> Animation {
        return Animation(duration: duration, delay: delay, springDamping: springDamping, initialSpringVelocity: initialSpringVelocity) { $0.bounds.size = size }
    }

    static func move(byX: CGFloat, y: CGFloat, duration: TimeInterval = 0.3, delay: TimeInterval = 0, springDamping: CGFloat = 1, initialSpringVelocity: CGFloat = 0) -> Animation {
        return Animation(duration: duration, delay: delay, springDamping: springDamping, initialSpringVelocity: initialSpringVelocity) {
            $0.center.x = $0.center.x + byX
            $0.center.y = $0.center.y + y
        }
    }

    static func scale(scaleX: CGFloat, y: CGFloat, duration: TimeInterval = 0.3, delay: TimeInterval = 0, springDamping: CGFloat = 1, initialSpringVelocity: CGFloat = 0) -> Animation {
        return Animation(duration: duration, delay: delay, springDamping: springDamping, initialSpringVelocity: initialSpringVelocity) { $0.transform = CGAffineTransform(scaleX: scaleX, y: y) }
    }

    static func transform(transform: CGAffineTransform, duration: TimeInterval = 0.3, delay: TimeInterval = 0, springDamping: CGFloat = 1, initialSpringVelocity: CGFloat = 0) -> Animation {
        return Animation(duration: duration, delay: delay, springDamping: springDamping, initialSpringVelocity: initialSpringVelocity) { $0.transform = transform }
    }
}

/**
    Animate a group of elements sequentially

    Example:
    ```
     animate(
         contentImageView.animate(
             .fadeIn()
         ),
         titleLabel.animateInParallel(
             .fadeIn(),
             .scale(transform: .identity)
         )
     )
    ```
 */
public func animate(_ tokens: AnimationToken...) {
    animate(tokens)
}

public extension UIView {
    /**
        Syntactic sugar to allow simpler invocation at the call site.

        ```
        label.animate(
            .fadeIn(),
            .move(byX: 10, y: 10)
        )
        ```

        instead of
        ```
        label.animate([
            .fadeIn(),
            .move(byX: 10, y: 10)
        ])
        ```
     */
    @discardableResult func animate(_ animations: Animation...) -> AnimationToken {
        return animate(animations)
    }

    /**
        Syntactic sugar to allow simpler invocation at the call site.

        ```
        label.animateInParallel(
            .fadeIn(),
            .move(byX: 10, y: 10)
        )
        ```

        instead of
        ```
        label.animateInParallel([
            .fadeIn(),
            .move(byX: 10, y: 10)
        ])
        ```
     */
    @discardableResult func animateInParallel(_ animations: Animation...) -> AnimationToken {
        return animateInParallel(animations)
    }
}

public extension UIView {
    /**
        Execute multiple animations on a UIView sequentially

        Example:
        ```
         titleLabel.animate(
             .fadeIn(),
             .scale(transform: .identity)
         )
        ```
     */
    @discardableResult func animate(_ animations: [Animation]) -> AnimationToken {
        return AnimationToken(
            view: self,
            animations: animations,
            mode: .inSequence
        )
    }

    /**
        Execute multiple animations on a UIView in parallel

        Example:
        ```
         titleLabel.animateInParallel(
             .fadeIn(),
             .scale(transform: .identity)
         )
        ```
     */
    @discardableResult func animateInParallel(_ animations: [Animation]) -> AnimationToken {
        return AnimationToken(
            view: self,
            animations: animations,
            mode: .inParallel
        )
    }
}

public func animate(_ tokens: [AnimationToken]) {
    guard !tokens.isEmpty else {
        return
    }

    var tokens = tokens
    let token = tokens.removeFirst()

    token.perform {
        animate(tokens)
    }
}

public final class AnimationToken {
    private let view: UIView
    private let animations: [Animation]
    private let mode: AnimationMode
    private var isValid = true

    internal init(view: UIView, animations: [Animation], mode: AnimationMode) {
        self.view = view
        self.animations = animations
        self.mode = mode
    }

    deinit {
        perform {}
    }

    internal func perform(completionHandler: @escaping () -> Void) {
        guard isValid else {
            return
        }

        isValid = false

        switch mode {
        case .inSequence:
            view.performAnimations(animations, completionHandler: completionHandler)
        case .inParallel:
            view.performAnimationsInParallel(animations, completionHandler: completionHandler)
        }
    }
}

public struct Animation {
    public let duration: TimeInterval
    public let delay: TimeInterval
    public let springDamping: CGFloat
    public let initialSpringVelocity: CGFloat
    public let closure: (UIView) -> Void
}

internal enum AnimationMode {
    case inSequence
    case inParallel
}

internal extension UIView {
    func performAnimations(_ animations: [Animation], completionHandler: @escaping () -> Void) {
        guard !animations.isEmpty else {
            return completionHandler()
        }

        var animations = animations
        let animation = animations.removeFirst()

        UIView.animate(
            withDuration: animation.duration,
            delay: animation.delay,
            usingSpringWithDamping: animation.springDamping,
            initialSpringVelocity: animation.initialSpringVelocity,
            options: .curveEaseOut,
            animations: {
                animation.closure(self)
            }, completion: { _ in
                self.performAnimations(animations, completionHandler: completionHandler)
            })
    }

    func performAnimationsInParallel(_ animations: [Animation], completionHandler: @escaping () -> Void) {
        guard !animations.isEmpty else {
            return completionHandler()
        }

        let animationCount = animations.count
        var completionCount = 0

        let animationCompletionHandler = {
            completionCount += 1

            if completionCount == animationCount {
                completionHandler()
            }
        }

        for animation in animations {
            UIView.animate(
                withDuration: animation.duration,
                delay: animation.delay,
                usingSpringWithDamping: animation.springDamping,
                initialSpringVelocity: animation.initialSpringVelocity,
                options: .curveEaseOut,
                animations: {
                    animation.closure(self)
                }, completion: { _ in
                    animationCompletionHandler()
                })
        }
    }
}
