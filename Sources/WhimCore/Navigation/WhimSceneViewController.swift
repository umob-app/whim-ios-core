import UIKit

// MARK: - Value

/// Basic building block for representing any value in the context of possible whim view controller variation.
public enum WhimSceneViewControllerValue<T> {
    case fullscreen(T)
    case multipart(top: T, bottom: T)
}

extension WhimSceneViewControllerValue: Equatable where T: Equatable {}

public extension WhimSceneViewControllerValue {
    var fullscreen: T? {
        guard case let .fullscreen(value) = self else { return nil }
        return value
    }

    var multipart: (top: T, bottom: T)? {
        guard case let .multipart(top, bottom) = self else { return nil }
        return (top, bottom)
    }
}

public extension WhimSceneViewControllerValue {
    var isFullscreen: Bool {
        guard case .fullscreen = self else { return false }
        return true
    }

    var isMultipart: Bool {
        guard case .multipart = self else { return false }
        return true
    }
}

// MARK: - View Controller

/// Represents available scenarios to render view controllers within whim flow.
public typealias WhimSceneViewController = WhimSceneViewControllerValue<UIViewController>

public extension WhimSceneViewController {
    /// A generic way to get all available `UIViewController`s.
    var viewControllers: [UIViewController] {
        switch self {
        case let .fullscreen(fullscreen): return [fullscreen]
        case let .multipart(top, bottom): return [top, bottom]
        }
    }

    /// A generic way to get all available `UIViewController`s.
    var fullscreenOrBottom: UIViewController {
        switch self {
        case let .fullscreen(fullscreen): return fullscreen
        case let .multipart(_, bottom): return bottom
        }
    }
}

// MARK: - Helpers

public extension WhimSceneViewControllerValue {
    /// Returns a whim view controller containing the results of mapping the given closure over the original value.
    /// Accepts mapping closures which accept either of the values as their parameters
    /// and return a transformed value of the same or of a different type.
    @discardableResult
    func map<U>(fullscreen: (T) -> U, multipart: (_ top: T, _ bottom: T) -> (top: U, bottom: U)) -> WhimSceneViewControllerValue<U> {
        switch self {
        case let .fullscreen(value):
            return .fullscreen(fullscreen(value))
        case let .multipart(top, bottom):
            let result = multipart(top, bottom)
            return .multipart(top: result.top, bottom: result.bottom)
        }
    }

    /// Returns a whim view controller containing the results of mapping the given closure over the original value.
    /// Accepts a single mapping closure which accepts either of the values as its parameter
    /// and return a transformed value of the same or of a different type.
    ///
    /// `transform` closure is applied to every value (i.e to both `top` and `bottom` in case of `multipart` option).
    @discardableResult
    func map<U>(_ transform: (T) -> U) -> WhimSceneViewControllerValue<U> {
        return map(fullscreen: transform, multipart: { top, bottom in (transform(top), transform(bottom)) })
    }
}

// Both methods are nonmutating as they're expected to be applied only to classes and not require having them defined as variables.
public extension WhimSceneViewControllerValue where T: AnyObject {
    /// Sets a property of the value by the given `keyPath` with the value wrapped into other whim view controller.
    /// Both, current and new whim view controllers should be of the same case, otherwise nothing will happen.
    func update<U>(keyPath: WritableKeyPath<T, U>, with value: WhimSceneViewControllerValue<U>) {
        switch (self, value) {
        case (var .fullscreen(lhs), let .fullscreen(rhs)):
            lhs[keyPath: keyPath] = rhs
        case (var .multipart(lhsTop, lhsBottom), let .multipart(rhsTop, rhsBottom)):
            lhsTop[keyPath: keyPath] = rhsTop
            lhsBottom[keyPath: keyPath] = rhsBottom
        default:
            return
        }
    }

    /// Sets a property of the value by the given `keyPath` with the new value returned by the given transform closure.
    func update<U>(keyPath: WritableKeyPath<T, U>, fullscreen: (T) -> U, multipart: (_ top: T, _ bottom: T) -> (top: U, bottom: U)) {
        update(keyPath: keyPath, with: map(fullscreen: fullscreen, multipart: multipart))
    }

    /// Sets a property of the value by the given `keyPath` with the new value.
    /// It is applied to every value (i.e to both `top` and `bottom` in case of `multipart` option).
    func update<U>(keyPath: WritableKeyPath<T, U>, with value: U) {
        update(keyPath: keyPath, with: map { _ in value })
    }
}
