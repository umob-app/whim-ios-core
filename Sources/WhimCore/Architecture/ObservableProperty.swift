import RxSwift
import RxRelay

/// Read-only observable property.
///
/// Allows to observe value updates and get its current value at any time.
/// Similar to `BehaviorRelay`, but doesn't allow mutating value as a part of public interface.
/// It's initialised with `BehaviorRelay` (or initial value with `Observable`), to mirror its updates, but hide mutations.
///
/// Inspired by [ReactiveSwift.Property](https://github.com/ReactiveCocoa/ReactiveSwift/blob/6.3.0/Sources/Property.swift#L496)
/// and [RxProperty](https://github.com/inamiy/RxProperty)
public final class ObservableProperty<Element>: ObservableConvertibleType {
    private let _value: BehaviorRelay<Element>
    private let scheduler: ImmediateSchedulerType?

    public var value: Element { _value.value }

    /// Initialize property with `BehaviorRelay` to wrap for read-only access, and a scheduler to receive updates by default.
    public init(_ value: BehaviorRelay<Element>, scheduler: ImmediateSchedulerType? = nil) {
        self.scheduler = scheduler
        _value = value
    }

    public func asObservable() -> Observable<Element> {
        let observable = _value.asObservable()
        return scheduler.map(observable.observe(on:)) ?? observable
    }
}

public extension ObservableProperty {
    convenience init(_ value: Element, scheduler: ImmediateSchedulerType? = nil) {
        self.init(BehaviorRelay(value: value), scheduler: scheduler)
    }

    convenience init(initial: Element, then observable: Observable<Element>, scheduler: ImmediateSchedulerType? = nil) {
        self.init(initial, scheduler: scheduler)
        _ = observable.bind(to: _value)
    }
}
