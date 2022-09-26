import UIKit

// MARK: - Animatable

/// Description of wether the value should be animated when applied or not.
public struct Animatable<T> {
    /// Modify value by keeping current animation config.
    public var value: T
    public private(set) var animated: Bool

    public init(_ value: T, animated: Bool = false) {
        self.value = value
        self.animated = animated
    }

    /// Set both, value and animation config, at once.
    public mutating func setValue(_ value: T, animated: Bool) {
        self.value = value
        self.animated = animated
    }

    /// Set both, value (by applying transfrmation function) and animation config, at once.
    public mutating func updateValue(_ transform: (inout T) -> Void, animated: Bool) {
        transform(&value)
        self.animated = animated
    }
}

extension Animatable: Equatable where T: Equatable {}

// MARK: - Custom Animatable

// sourcery: Random
/// Description of wether the value should be animated when applied or not, and how to animate it.
///
/// Uses same properties for animation as you'd use to call `UIView.animate(withDuration:delay:options:animations:completion:)`.
public struct CustomAnimatable<T> {
    // sourcery: Random
    public struct Animation: Hashable {
        public var duration: TimeInterval
        public var delay: TimeInterval
        public var options: UIView.AnimationOptions

        public init(duration: TimeInterval, delay: TimeInterval, options: UIView.AnimationOptions) {
            self.duration = duration
            self.delay = delay
            self.options = options
        }

        public static var defaultDelay: TimeInterval { 0 }
        public static var defaultOptions: UIView.AnimationOptions { [] }
    }

    /// Modify value by keeping current animation config.
    public var value: T
    public private(set) var animation: Animation?

    public init(_ value: T) {
        self.value = value
        self.animation = nil
    }

    public init(
        _ value: T,
        duration: TimeInterval,
        delay: TimeInterval = Animation.defaultDelay,
        options: UIView.AnimationOptions = Animation.defaultOptions
    ) {
        self.value = value
        self.animation = Animation(duration: duration, delay: delay, options: options)
    }

    /// Set value immediately without animation.
    public mutating func setValue(_ value: T) {
        self.value = value
        self.animation = nil
    }

    /// Set value immediately (by applying transfrmation function) without animation.
    public mutating func updateValue(_ transform: (inout T) -> Void) {
        transform(&value)
        self.animation = nil
    }

    /// Set both, value and animation config, at once.
    public mutating func setValueAnimated(
        _ value: T,
        duration: TimeInterval,
        delay: TimeInterval = Animation.defaultDelay,
        options: UIView.AnimationOptions = Animation.defaultOptions
    ) {
        self.value = value
        self.animation = Animation(duration: duration, delay: delay, options: options)
    }

    /// Set both, value (by applying transfrmation function) and animation config, at once.
    public mutating func updateValueAnimated(
        _ transform: (inout T) -> Void,
        duration: TimeInterval,
        delay: TimeInterval = Animation.defaultDelay,
        options: UIView.AnimationOptions = Animation.defaultOptions
    ) {
        transform(&value)
        self.animation = Animation(duration: duration, delay: delay, options: options)
    }
}

extension CustomAnimatable: Equatable where T: Equatable {}
extension CustomAnimatable: Hashable where T: Hashable {}

extension UIView.AnimationOptions: Hashable {}
