import Foundation
import RxSwift
import RxTest
import Quick
import Nimble

// MARK: - Recorded Events

public typealias RecordedEvents<T> = [RecordedEvent<T>]

/// Wrapper over RxTest nested abstractions `Recorded<Event<T>>`, as it allows extending it in more friendly ways.
public struct RecordedEvent<T> {
    public let time: TestTime
    public let value: Event<T>

    public var element: T? {
        value.element
    }

    public init(time: TestTime, value: Event<T>) {
        self.time = time
        self.value = value
    }

    public init(event: Recorded<Event<T>>) {
        time = event.time
        value = event.value
    }

    public func map<U>(_ transform: (T) throws -> U) -> RecordedEvent<U> {
        RecordedEvent<U>(time: time, value: value.map(transform))
    }

    public func map<U>(_ keyPath: KeyPath<T, U>) -> RecordedEvent<U> {
        map { $0[keyPath: keyPath] }
    }
}

extension RecordedEvent: Equatable where T: Equatable {}

public extension Recorded {
    init<T>(event: RecordedEvent<T>) where Value == Event<T> {
        self.init(time: event.time, value: event.value)
    }
}

// MARK: - Recorded Events Matchers

/// Assert a list of Recorded events has emitted the provided elements.
/// This method does not take event times into consideration.
///
/// This method will assert a failure if any stop events have been emitted (e.g. `completed` or `error`).
///
/// - Parameters:
///     - stream: Array of recorded events.
///     - elements: Array of expected elements.
///     - file: The absolute path to the file containing the example. A sensible default is provided.
///     - line: The line containing the example. A sensible default is provided.
public func XCTAssertRecordedElements<Element: Equatable>(_ stream: [RecordedEvent<Element>], _ elements: [Element], file: StaticString = #file, line: UInt = #line) {
    XCTAssertRecordedElements(stream.map(Recorded.init), elements, file: file, line: line)
}

/// Assert a Recorded event has emitted the provided element.
/// This method does not take event time into consideration.
///
/// This method will assert a failure if stop event has been emitted (e.g. `completed` or `error`).
///
/// - Parameters:
///     - event: Recorded event.
///     - element: Expected element.
///     - file: The absolute path to the file containing the example. A sensible default is provided.
///     - line: The line containing the example. A sensible default is provided.
public func XCTAssertRecordedElement<Element: Equatable>(_ event: RecordedEvent<Element>, _ element: Element, file: StaticString = #file, line: UInt = #line) {
    XCTAssertRecordedElements([Recorded(event: event)], [element], file: file, line: line)
}

/// A Nimble matcher that succeeds when the actual recorded element is nil.
public func beNilElement<T>() -> Nimble.Predicate<RecordedEvent<T?>> {
    .simpleNilable("be nil") { actualExpression in
        let actualValue = try actualExpression.evaluate()
        switch actualValue?.value.element {
        case .some(.none), .none: return PredicateStatus(bool: true)
        default: return PredicateStatus(bool: false)
        }
    }
}

/// A Nimble matcher allowing comparison of collections of recorded elements and expected values with optional type.
public func equalElements<T: Equatable>(_ expectedValue: [T?]) -> Nimble.Predicate<RecordedEvents<T>> {
    .define("equal <\(stringify(expectedValue))>") { actualExpression, msg in
        guard let actualValue = try actualExpression.evaluate() else {
            return PredicateResult(
                status: .fail,
                message: msg.appendedBeNilHint()
            )
        }
        if let stopEvent = actualValue.first(where: { $0.value.isStopEvent }) {
            return PredicateResult(bool: false, message: .appends(msg, "A non-next stop event has been emitted: \(stopEvent)"))
        }
        let streamElements = actualValue.map { event -> T in
            guard case .next(let element) = event.value else {
                fatalError("Non-next stop event should cause assertion")
            }
            return element
        }
        let matches = expectedValue == streamElements
        return PredicateResult(bool: matches, message: msg)
    }
}

/// A Nimble matcher that succeeds when the actual value recorded element is equal to the expected value.
public func equalElement<T: Equatable>(_ expectedValue: T?) -> Nimble.Predicate<RecordedEvent<T>> {
    .define("equal <\(stringify(expectedValue))>") { actualExpression, msg in
        let actualValue = try actualExpression.evaluate()
        switch (expectedValue, actualValue) {
        case (nil, _?):
            return PredicateResult(status: .fail, message: msg.appendedBeNilHint())
        case (nil, nil), (_, nil):
            return PredicateResult(status: .fail, message: msg)
        case (let expected?, let actual?):
            switch actual.value {
            case let .next(value):
                return PredicateResult(bool: value == expected, message: msg)
            default:
                return PredicateResult(bool: false, message: .appends(msg, "A non-next stop event has been emitted: \(actual.value)"))
            }
        }
    }
}

/// A Nimble matcher that succeeds when the actual recorded element is the same instance as the expected instance.
public func beIdenticalToElement<T>(_ expected: Any?) -> Nimble.Predicate<RecordedEvent<T>> {
    .define { actualExpression in
        let actual = (try actualExpression.evaluate())?.element as AnyObject?

        let bool = actual === (expected as AnyObject?) && actual !== nil
        return PredicateResult(
            bool: bool,
            message: .expectedCustomValueTo(
                "be identical to \(identityAsString(expected))",
                actual: "\(identityAsString(actual))"
            )
        )
    }
}

private func identityAsString(_ value: Any?) -> String {
    let anyObject = value as AnyObject?
    if let value = anyObject {
        return NSString(format: "<%p>", unsafeBitCast(value, to: Int.self)).description
    } else {
        return "nil"
    }
}

// MARK: - Verify Store

/// When implementing a test use the `verifyStore(given:when:then:)` helper method from TestUtilities.
///
/// Inspired by [BabylonHealth UnitTestingViewModels](https://github.com/babylonhealth/ios-playbook/blob/master/Cookbook/Technical-Documents/UnitTestingViewModels.md)
///
/// - Parameters:
///     - schedulerResolution: Underlying scheduler's config parameter. Real time [TimeInterval] = ticks * resolution.
///         Defaults to `1.0`.
///     - given: Is used to create a store. It accepts a `TestScheduler` that you pass to the store initializer.
///         It allows to control events displatch via its `advanceTo` method later in the `when` closure.
///         And returns store with its observable state, which is needed to record all state transitions and time when it happened.
///     - when: A closure where the actual interaction with store should happen.
///         To "interact" with a store you should call its `dispatch` method and provide an action.
///         This effectively simulates other services' calls or user interaction with a screen managed by this store.
///         After sending an event you will need to call `scheduler.advanceBy()`.
///         Until this method is called at least once no events will be produced by any observable in the store's state machine.
///         As soon as `advanceBy` is called it will "release" the first event and so on.
///         You can also use `advanceTo` for absolute timings or even `start` to keep tasks executing until its queue is empty.
///
///         In practice, usually 10 virtual time units is enough to advance each step.
///         However you might find yourself performing time-sensitive testing (i.e. with delay operator).
///         And this is when you'll may need to customize virtual time unit steps and even `schedulerResolution` parameter.
///
///         Pretty good tutorial about RxTest in general and how to perform time-sensitive testing can be found at
///         [raywenderlich.com](https://www.raywenderlich.com/7408-testing-your-rxswift-code#toc-anchor-006)
///     - then: A closure where all the assertions happen.
///         You usually assert aggregated states ensuring that store's state machine goes through expected transitions.
///         You can as well assert that mocks' methods where called correctly, etc.
///
/// - Returns: An instance of underlying ``StoreVerification`` to be able to compose multiple verifications if needed.
///
///     Note: Each next verification applied to the same instance will continue from where the previous one has left,
///     as underlying timer and its virtual clock is shared across the instance.
///
/// Example:
/// ```swift
/// verifyStore(
///     given: { scheduler -> (AuthService, Observable<AuthService.State>) in
///         let store = AuthService(scheduler: scheduler, service: WikiNetworkingMock())
///         return (store, store.state)
///     },
///     when: { store, scheduler in
///         // you start workflow by advancing scheduler
///         // so that system would start working
///         scheduler.advanceBy(10)
///         // and then rotate - performing work and advancing scheduler
///         store.loginAsGuest()
///         // finish by advancing scheduler so that last step is executed
///         scheduler.advanceBy(10)
///     },
///     then: { events in
///         // RxTest provides custom assertions
///         // to easily verify events with actual states
///         // when other info (their time) not needed
///         XCTAssertRecordedElements(events, [
///             .idle,
///             .login(.succeeded(token: nil, user: .guest))
///         ])
///     }
/// )
/// ```
@discardableResult
public func verifyStore<Store, State>(
    schedulerResolution: Double = 1.0,
    given: (TestScheduler) -> (Store, Observable<State>),
    when: (Store, TestScheduler) -> Void,
    then: (RecordedEvents<State>) -> Void
) -> StoreVerification<Store, State> {
    StoreVerification<Store, State>(schedulerResolution: schedulerResolution, given: given)
        .verify(when: when, then: then)
}

/// A simple wrapper over store verification.
///
/// Allows splitting `given` part from others and gives the ability to reuse store creation (i.e. using Quick `beforeEach`).
///
/// Example:
/// ```swift
/// let sut = StoreVerification<AuthService, AuthService.State>(given: { scheduler in
///     let store = AuthService(scheduler: scheduler, service: WikiNetworkingMock())
///     return (store, store.state)
/// })
///
/// // ...
///
/// sut.verify(when: { store, scheduler in
///     // you start workflow by advancing scheduler
///     // so that system would start working
///     scheduler.advanceBy(10)
///     // and then rotate - performing work and advancing scheduler
///     store.loginAsGuest()
///     // finish by advancing scheduler so that last step is executed
///     scheduler.advanceBy(10)
/// },
/// then: { events in
///     // RxTest provides custom assertions
///     // to easily verify events with actual states
///     // when other info (their time) not needed
///     XCTAssertRecordedElements(events, [
///         .idle,
///         .login(.succeeded(token: nil, user: .guest))
///     ])
/// })
/// ```
public struct StoreVerification<Store, State> {
    private let scheduler: TestScheduler
    private let observer: TestableObserver<State>
    private let store: Store
    private let disposeBag = DisposeBag()

    /// - Parameters:
    ///     - schedulerResolution: Underlying scheduler's config parameter. Real time [TimeInterval] = ticks * resolution.
    ///         Defaults to `1.0`.
    ///     - given: Is used to create a store. It accepts a `TestScheduler` that you pass to the store initializer.
    ///         It allows to control events displatch via its `advanceBy`, `advanceTo` or `start` methods later in the `when` closure.
    ///         And returns store with its observable state, which is needed to record all state transitions and time when it happened.
    public init(schedulerResolution: Double = 1.0, given: (TestScheduler) -> (Store, Observable<State>)) {
        scheduler = TestScheduler(initialClock: 0, resolution: schedulerResolution)
        observer = scheduler.createObserver(State.self)
        let (store, state) = given(scheduler)
        self.store = store
        state.subscribe(observer).disposed(by: disposeBag)
    }

    /// Verify given system under test (SUT) with different actions and assertions.
    ///
    /// - Parameters:
    ///     - when: A closure where the actual interaction with store should happen.
    ///         To "interact" with a store you should call its `dispatch` method and provide an action.
    ///         This effectively simulates other services' calls or user interaction with a screen managed by this store.
    ///         After sending an event you will need to call `scheduler.advanceBy()`.
    ///         Until this method is called at least once no events will be produced by any observable in the store's state machine.
    ///         As soon as `advanceBy` is called it will "release" the first event and so on.
    ///         You can also use `advanceTo` for absolute timings or even `start` to keep tasks executing until its queue is empty.
    ///
    ///         In practice, usually 10 virtual time units is enough to advance each step.
    ///         However you might find yourself performing time-sensitive testing (i.e. with delay operator).
    ///         And this is when you'll may need to customize virtual time unit steps and even `schedulerResolution` parameter.
    ///
    ///         Pretty good tutorial about RxTest in general and how to perform time-sensitive testing can be found at
    ///         [raywenderlich.com](https://www.raywenderlich.com/7408-testing-your-rxswift-code#toc-anchor-006)
    ///     - then: A closure where all the assertions happen.
    ///         You usually assert aggregated states ensuring that store's state machine goes through expected transitions.
    ///         You can as well assert that mocks' methods where called correctly, etc.
    ///
    /// - Returns: `self` to compose multiple verifications if needed.
    ///
    ///     Note: Each next verification applied to the same instance will continue from where the previous one has left,
    ///     as underlying timer and its virtual clock is shared across the instance.
    @discardableResult
    public func verify(
        when: (Store, TestScheduler) -> Void,
        then: (RecordedEvents<State>) -> Void
    ) -> StoreVerification {
        when(store, scheduler)
        then(observer.events.map(RecordedEvent.init))
        return self
    }

    /// Sometimes you might want to compose test preparation from multiple steps, i.e. nested Quick contexts.
    /// This is when this method can be handy.
    ///
    /// - Note: Each next `when` block applied to the same instance will continue from where the previous one has left,
    ///     as underlying timer and its virtual point in time is shared across the instance.
    @discardableResult
    public func when(_ action: (Store, TestScheduler) -> Void) -> StoreVerification {
        action(store, scheduler)
        return self
    }

    /// In case you just want to perform an assertion, use this method.
    @discardableResult
    public func then(_ assert: (RecordedEvents<State>) -> Void) -> StoreVerification {
        assert(observer.events.map(RecordedEvent.init))
        return self
    }
}

//public extension StoreVerification {
//    init<Action>(schedulerResolution: Double = 1.0, givenService: (TestScheduler) -> Store) where Store: AbstractService<State, Action> {
//        self.init(schedulerResolution: schedulerResolution, given: { scheduler in
//            let store = givenService(scheduler)
//            return (store, store.state.asObservable())
//        })
//    }
//}

// MARK: Test Scheduler

public extension TestScheduler {
    /// Advances the scheduler's clock by the specified time interval, running all work till that point.
    ///
    /// - Parameter virtualInterval: Relative time to advance the scheduler's clock by.
    func advanceBy(_ virtualInterval: VirtualTimeInterval) {
        // Unfortunately we can't access VirtualTimeScheduler's `_converter` to correctly perform `offsetVirtualTime`.
        // Fortunately, TestScheduler uses `TestSchedulerVirtualTimeConverter` and its `offsetVirtualTime` is a simple addition.
        advanceTo(clock + virtualInterval)
    }
}
