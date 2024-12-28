import Foundation

final public class Atomic<A> {
    private let queue = DispatchQueue(label: "Atomic Serial Queue")
    private var _value: A
    
    public init(_ value: A) {
        _value = value
    }
    
    /// Get your Value, if you want to mutate it, use mutate method
    public var value: A {
        get {
            return queue.sync{ self._value }
        }
    }
    
    /// Mutate your value
    public func mutate(_ transform: (inout A) -> ()) {
        queue.sync {
            transform(&self._value)
        }
    }
}
