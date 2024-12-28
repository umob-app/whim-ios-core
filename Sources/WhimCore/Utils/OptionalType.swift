import Foundation

/// https://gist.github.com/alskipp/e71f014c8f8a9aa12b8d8f8053b67d72

public protocol OptionalType {
    associatedtype Wrapped

    var optional: Wrapped? { get }
}

extension Optional: OptionalType {
    public var optional: Wrapped? { return self }
}
