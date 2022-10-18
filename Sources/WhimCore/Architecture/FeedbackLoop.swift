import Foundation
import RxSwift
import RxRelay

// MARK: - Feedbacks:

/// Unidirectional Reactive Architecture.
///
/// Feedback Loop System implementation inspired by:
/// - [RxFeedback](https://github.com/NoTests/RxFeedback.swift)
/// - [ReactiveFeedback](https://github.com/babylonhealth/ReactiveFeedback)
/// - [ReactiveCocoa/Loop](https://github.com/ReactiveCocoa/Loop)
/// - [CombineFeedback](https://github.com/sergdort/CombineFeedback)
///
/// More links:
///  - [Trafi/States](https://github.com/trafi/states)
///
/// The intention to build custom implementation was to be closer to the ReactiveFeedback (now Loop) and CombineFeedback
/// as these implementations are more actively supported and should allow easier transition to Combine in the future.
///
/// ReactiveFeedback (now Loop) and CombineFeedback are very much the same and I trust their implementation,
/// as ReactiveFeedback/Loop is used in BabylonHealth iOS application (in production) and is developed bvy the community.
/// That said, it should be easier for us to create similar Combine implementation based on CombineFeedback.
///
/// Here's a diagram and a brief description demonstrating how feedbacks are built on top of one another:
///
/// ```
///                                 ┌──────────────┐
///                                 │    events    │
///                                 └──────────────┘
///                                         │
///                ┌──────────────────┬─────┴────────────┬──────────────────┐
///                │                  │                  │                  │
///                ▼                  ▼                  ▼                  ▼
///        ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
///        │     just     │   │  withLatest  │   │   merging    │   │  imperative  │
///        └──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
///                │                  │
///         ┌──────┴──────┐           │
///         │             │           │
///         ▼             ▼           │
///     ┌───────┐    ┌─────────┐      │
///     │ empty │    │  never  │      │
///     └───────┘    └─────────┘      │
///                                   │
///         ┌─────────────────────────┼───────────────────────────┬───────────────────────┐
///         │                         │                           │                       │
///         ▼                         ▼                           ▼                       ▼
/// ┌──────────────┐   ┌────────────────────────────┐   ┌──────────────────┐   ┌────────────────────┐
/// │  lensing /   │   │ lensingSkippingRepeated /  │   │ skippingRepeated │   │ firstValueAfterNil │
/// │  extracting  │   │ extractingSkippingRepeated │   └──────────────────┘   └────────────────────┘
/// └──────────────┘   └────────────────────────────┘                                     │
///                                                                                       ▼
///                                                                              ┌─────────────────┐
///                                                                              │ whenBecomesTrue │
///                                                                              └─────────────────┘
/// ```
///
/// - `init(events:)`
///    is a very base initializer, and everything else is built on top of it,
///    it receives a function with scheduler and stream of state updates and events,
///    and returns a stream of new events, which will be used to update state through system's reducer.
///
///    - `just(effects:)`
///       is a simple feedback that ignores any state updates or emitted events, but just streams its own events,
///       it is very handy to pass events into the system from the outside world (UI, notifications, etc).
///
///       - `empty()` and `never()` are shortcuts for `just(effects:)`
///          with only `Observable.empty()` and `Observable.never()` passed as effects respectively.
///          prior one completed immediately, latter one never completes by itself.
///
///    - `withLatest(transform:effects:)`
///       is used to transform either stream of state updates or emitted events into stream of other values,
///       each new value from the resulting stream will generate new side-effect and kill previous one if such is in progress.
///       it is treated as a baseline for other common transformations, but can be used on its own to achieve more specific results.
///
///    - `merging(transform:effects:)`
///       is used to transform either stream of state updates or emitted events into stream of other values,
///       each new value from the resulting stream will generate new side-effect, and will not kill those that are already running
///       unlike `withLatest`, if there're multiple effects alive, their events streams will be merged together in the system.
///
///       - `lensing(transform:effects:)` or `extracting(transform:effects:)`
///          sorry for the name, it comes from FP and is common to other libraries, so I decide to keep it,
///          it transforms state into one of its parts if such exists or `nil` if state isn't in a needed shape,
///          you basically focus on a sub-state as if you're using a lense to zoom into it, thus the name.
///          if transform result is `nil`, no new effect will be triggered and existing effect will be killed if such exists,
///          however if it returns value, new effect will be triggered with that value and existing one will be killed if exists.
///          same for `extracting` but here we're extracting a payload from the emitted event instead of lensing into sub-state.
///
///       - `lensingSkippingRepeated(transform:effects:)` or `extractingSkippingRepeated(transform:effects:)`
///          very much the same as `lensing`, but in case we get same results of transformation in a row, duplicates will be ignored,
///          hence if a feedback was triggered by some value, and transform results with the same value again and again,
///          existing effect will not be killed.
///          however if it results with a new value or `nil`, any previously started effect will be killed.
///          same for `extracting` but here we're extracting a payload from the emitted event instead of lensing into sub-state.
///
///       - `skippingRepeated(transform:effects:)`
///          starts new effect with a whole state every time transform results with a new value, distinct from a previous one,
///          if transform produces multiple similar values in a row, existing effect will not be killed,
///          however if transform produces a value distinct from a previous one, existing effect will be killed if such exists.
///
///       - `firstValueAfterNil(transform:effects:)`
///          starts new effect when a value is received after a sequence of `nil`,
///          other values are ignored and original value's effect keeps on living,
///          however, once `nil` is received, any outstanding effect is killed.
///          same is for `whenBecomesTrue(predicate:effets:)`, except instead of value/nil there's true/false respectively.
///
///    - `imperative(effects:)`:
///       can be used if reactive code is not preferred (i.e. hard to understand/maintain by the team),
///       it is triggered each time an event is emitted (by the system or from external source),
///       it receives an event and a state of the system at that time, and a callback to emmit new event as a result of its work.

public struct Feedback<State, Event> {
    public typealias Input = (state: State, event: Event?)
    public typealias Effect = Observable<Event>

    public let events: (ImmediateSchedulerType, Observable<Input>) -> Observable<Event>

    /// Creates an arbitrary Feedback, which evaluates side effects reactively
    /// to the latest state and/or event, and eventually produces new events that affect the state.
    ///
    /// - parameter events: The transform which derives an `Observable` of events from the latest state and/or event.
    public init(events: @escaping (ImmediateSchedulerType, Observable<Input>) -> Observable<Event>) {
        self.events = events
    }
}

// MARK: • Latest

extension Feedback {
    /// Creates a Feedback which re-evaluates the given effect every time the
    /// `Observable` derived from the latest state yields a new value.
    ///
    /// If the previous effect is still alive when a new one is about to start, the previous one will be automatically cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform which derives an `Observable` of values from the latest state.
    ///   - effects: The side effect accepting transformed values and yielding events that eventually affect the state.
    public static func withLatest<U>(
        state transform: @escaping (Observable<State>) -> Observable<U>,
        effects: @escaping (U) -> Effect
    ) -> Feedback {
        Feedback(withLatest: { transform($0.filter(\.event.isNil).map(\.state)) }, effects: effects)
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// `Observable` derived from the emitted events yields a new value.
    ///
    /// If the previous effect is still alive when a new one is about to start, the previous one will be automatically cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform which derives an `Observable` of values from the latest event.
    ///   - effects: The side effect accepting transformed values and yielding events that eventually affect the state.
    public static func withLatest<U>(
        events transform: @escaping (Observable<Event>) -> Observable<U>,
        effects: @escaping (U) -> Effect
    ) -> Feedback {
        Feedback(withLatest: { transform($0.compactMap(\.event)) }, effects: effects)
    }

    private init<U>(withLatest transform: @escaping (Observable<Input>) -> Observable<U>, effects: @escaping (U) -> Effect) {
        self.events = { scheduler, input in
            // NOTE: `observeOn(_:)` should be applied on the inner observable, so
            //       that cancellation due to state changes would be able to
            //       cancel outstanding events that have already been scheduled.
            transform(input).flatMapLatest { effects($0).observe(on: scheduler) }
        }
    }
}

// MARK: • Merging

extension Feedback {
    /// Creates a Feedback which evaluates the given effect every time the
    /// `Observable` derived from the latest state yields a new value.
    ///
    /// If the previous effect is still alive when a new one is about to start, both will be merged into a single events stream.
    ///
    /// - parameters:
    ///   - transform: The transform which derives an `Observable` of values from the latest state.
    ///   - effects: The side effect accepting transformed values and yielding events that eventually affect the state.
    public static func merging<U>(
        state transform: @escaping (Observable<State>) -> Observable<U>,
        effects: @escaping (U) -> Effect
    ) -> Feedback {
        Feedback(merging: { transform($0.filter(\.event.isNil).map(\.state)) }, effects: effects)
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// `Observable` derived from the emitted events yields a new value.
    ///
    /// If the previous effect is still alive when a new one is about to start, both will be merged into a single events stream.
    ///
    /// - parameters:
    ///   - transform: The transform which derives an `Observable` of values from the latest event.
    ///   - effects: The side effect accepting transformed values and yielding events that eventually affect the state.
    public static func merging<U>(
        events transform: @escaping (Observable<Event>) -> Observable<U>,
        effects: @escaping (U) -> Effect
    ) -> Feedback {
        Feedback(merging: { transform($0.compactMap(\.event)) }, effects: effects)
    }

    private init<U>(merging transform: @escaping (Observable<Input>) -> Observable<U>, effects: @escaping (U) -> Effect) {
        self.events = { scheduler, input in
            // NOTE: `observeOn(_:)` should be applied on the inner observable, so
            //       that cancellation due to state changes would be able to
            //       cancel outstanding events that have already been scheduled.
            transform(input).flatMap { effects($0).observe(on: scheduler) }
        }
    }
}

// MARK: • Transformational

extension Feedback {
    /// Creates a Feedback which re-evaluates the given effect every time the state changes.
    ///
    /// If the previous effect is still alive when a new one is about to start, the previous one will be automatically cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform to apply on the state.
    ///   - effects: The side effect accepting transformed values and yielding events that eventually affect the state.
    public static func lensing<Value>(
        state transform: @escaping (State) -> Value?,
        effects: @escaping (Value) -> Effect
    ) -> Feedback {
        Feedback.withLatest(
            state: { $0.map(transform) },
            effects: { $0.map(effects)?.asObservable() ?? .empty() }
        )
    }

    /// Creates a Feedback which re-evaluates the given effect every time a specific event is emitted.
    ///
    /// If the previous effect is still alive when a new one is about to start, the previous one will be automatically cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform to apply on the event.
    ///   - effects: The side effect accepting transformed values and yielding events that eventually affect the state.
    public static func extracting<Payload>(
        payload transform: @escaping (Event) -> Payload?,
        effects: @escaping (Payload) -> Effect
    ) -> Feedback {
        Feedback.withLatest(
            events: { $0.map(transform) },
            effects: { $0.map(effects)?.asObservable() ?? .empty() }
        )
    }

    /// Creates a Feedback which re-evaluates the given effect every time the state changes,
    /// and the transform consequentially yields a new value distinct from the last yielded value.
    ///
    /// If the previous effect is still alive when a new one is about to start, the previous one will be automatically cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform to apply on the state.
    ///   - effects: The side effect accepting transformed values and yielding events that eventually affect the state.
    public static func lensingSkippingRepeated<Value: Equatable>(
        state transform: @escaping (State) -> Value?,
        effects: @escaping (Value) -> Effect
    ) -> Feedback {
        Feedback.withLatest(
            state: { $0.map(transform).distinctUntilChanged() },
            effects: { $0.map(effects)?.asObservable() ?? .empty() }
        )
    }

    /// Creates a Feedback which re-evaluates the given effect every time the state changes,
    /// and the transform consequentially yields a new value distinct from the last yielded value.
    ///
    /// If the previous effect is still alive when a new one is about to start, the previous one will be automatically cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform to apply on the state.
    ///   - equals: The ad-hoc equality check to apply to the result of `transform`, in case conformance to `Equatable` isn't convenient.
    ///   - effects: The side effect accepting transformed values and yielding events that eventually affect the state.
    public static func lensingSkippingRepeated<Value>(
        state transform: @escaping (State) -> Value?,
        equals: @escaping (Value?, Value?) -> Bool,
        effects: @escaping (Value) -> Effect
    ) -> Feedback {
        Feedback.withLatest(
            state: { $0.map(transform).distinctUntilChanged(equals) },
            effects: { $0.map(effects)?.asObservable() ?? .empty() }
        )
    }

    /// Creates a Feedback which re-evaluates the given effect every time a specific event is emitted,
    /// and the transform consequentially yields a new value distinct from the last yielded value.
    ///
    /// If the previous effect is still alive when a new one is about to start, the previous one will be automatically cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform to apply on the event.
    ///   - effects: The side effect accepting transformed values and yielding events that eventually affect the state.
    public static func extractingSkippingRepeated<Payload: Equatable>(
        payload transform: @escaping (Event) -> Payload?,
        effects: @escaping (Payload) -> Effect
    ) -> Feedback {
        Feedback.withLatest(
            events: { $0.map(transform).distinctUntilChanged() },
            effects: { $0.map(effects)?.asObservable() ?? .empty() }
        )
    }

    /// Creates a Feedback which re-evaluates the given effect every time the state changes,
    /// and the transform consequentially yields a new value distinct from the last yielded value.
    ///
    /// If the previous effect is still alive when a new one is about to start, the previous one will be automatically cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform to apply on the state.
    ///   - effects: The side effect accepting the state and yielding events that eventually affect the state.
    public static func skippingRepeated<Value: Equatable>(
        state transform: @escaping (State) -> Value,
        effects: @escaping (State) -> Effect
    ) -> Feedback {
        Feedback.withLatest(
            state: { $0.distinctUntilChanged(transform) },
            effects: { effects($0).asObservable() }
        )
    }

    /// Create a Feedback which (re)starts the effect every time `transform` emits a non-nil value after a sequence
    /// of `nil`, and ignore all the non-nil value afterwards. It does so until `transform` starts emitting a `nil`,
    /// at which point the feedback cancels any outstanding effect.
    ///
    /// - parameters:
    ///   - transform: The transform to select a specific part of the state, or to cancel the outstanding effect by returning `nil`
    ///   - effects: The side effect accepting the first non-nil value produced by `transform`, and yielding events
    ///              that eventually affect the state.
    public static func firstValueAfterNil<Value>(
        state transform: @escaping (State) -> Value?,
        effects: @escaping (Value) -> Effect
    ) -> Feedback {
        Feedback.withLatest(
            state: { $0.map(transform).distinctUntilChanged(\.isNil) },
            effects: { $0.map(effects)?.asObservable() ?? .empty() }
        )
    }

    /// Creates a Feedback which evaluates the given effect when the predicate transitions to `true`,
    /// and cancels the outstanding effect when the predicate transitions to `false`.
    ///
    /// In other words, this variant treats the output of `predicate` as a binary signal.
    /// It starts the effect when there is a positive edge, and cancels the outstanding effect (if any) on a negative edge.
    ///
    /// - parameters:
    ///   - predicate: The predicate to indicate whether effects should start or be cancelled.
    ///   - effects: The side effect accepting the state and yielding events that eventually affect the state.
    public static func whenBecomesTrue(
        state predicate: @escaping (State) -> Bool,
        effects: @escaping (State) -> Effect
    ) -> Feedback {
        Feedback.firstValueAfterNil(
            state: { predicate($0) ? $0 : nil },
            effects: effects
        )
    }

    /// Creates a Feedback which re-evaluates the given effect every time the state changes or event is emitted.
    ///
    /// If the previous effect is still alive when a new one is about to start, the previous one would automatically be cancelled.
    ///
    /// - parameter effects: The side effect accepting the state and/or events and yielding events that eventually affect the state.
    public init(effects: @escaping (Input) -> Effect) {
        self.init(withLatest: { $0 }, effects: effects)
    }
}

// MARK: • Imperative

public extension Feedback {
    /// Creates an arbitrary Feedback, which allows treating it as a simple imperative method.
    ///
    /// - NOTE: reducer is always first to handle the event, thus if both reducer and a feedback decide to handle same event,
    ///         reducer will update state first and feedback will receive that event with already updated state.
    ///         this decision helps us to avoid race condition and to keep predictable behavior.
    ///
    /// - parameter effects: A function that receives new events along with a state update caused by that event,
    ///                      and a callback yielding events that eventually affect the state.
    ///
    /// Example:
    /// ```
    /// Feedback.imperative(effects: { callback in
    ///     let someLocalState: Int = 42
    ///
    ///     return { state, event in
    ///         if event.shouldDoSomething && state.fitsThatGoal {
    ///             doSomethingAsync { result in
    ///                 callback(.didFinishDoingSomething(result))
    ///             }
    ///         }
    ///     }
    /// })
    /// ```
    static func imperative(effects: @escaping (@escaping (Event) -> Void) -> (State, Event) -> Void) -> Feedback {
        Feedback(events: { scheduler, input in
            Observable.create { observer in
                input.compactMap(WhimCore.zip).subscribe(onNext: effects({ event in observer.on(.next(event)) }))
            }
            .observe(on: scheduler)
        })
    }
}

// MARK: • Creational

public extension Feedback {
    /// Creates an arbitrary Feedback, which evaluates side effects reactively and eventually produces events that affect the state.
    ///
    /// - parameter effects: The side effect yielding events that eventually affect the state.
    static func just(effects: Effect) -> Feedback {
        Feedback(events: { scheduler, _ in
            effects.observe(on: scheduler)
        })
    }

    /// Creates an arbitrary Feedback, with empty effect (basically, sends single `Completed` Rx event).
    ///
    /// Creates `empty()` Rx Observable underneath as the effect.
    static func empty() -> Feedback {
        .just(effects: .empty())
    }

    /// Creates an arbitrary Feedback, with non-terminating effect, which can be used to denote an infinite duration.
    ///
    /// Creates `never()` Rx Observable underneath as the effect.
    static func never() -> Feedback {
        .just(effects: .never())
    }
}

// MARK: - System

public final class FeedbackSystem<State, Event>: ObservableConvertibleType {
    public typealias Input = Feedback<State, Event>.Input

    public let state: ObservableProperty<State>

    private let eventsRelay: PublishRelay<Event>
    public var events: Observable<Event> {
        eventsRelay.asObservable()
    }

    private let disposeBag = DisposeBag()

    public init(
        initial: State,
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance,
        reduce: @escaping (inout State, Event) -> Void,
        feedbacks: [Feedback<State, Event>]
    ) {
        let stateRelay = BehaviorRelay(value: initial)
        self.state = ObservableProperty(stateRelay, scheduler: scheduler)
        self.eventsRelay = PublishRelay()

        Observable<(state: State, event: Event?)>.deferred {
            let state = ReplaySubject<State>.create(bufferSize: 1)
            let events = PublishSubject<Event>()
            let stateWithEvents: Observable<Input> = Observable.merge(
                state.map { ($0, nil) },
                events.withLatestFrom(state, resultSelector: { e, s in (s, e) })
            )
            let asyncScheduler = scheduler.async
            let outputs = feedbacks.map { feedback in
                feedback.events(asyncScheduler, stateWithEvents)
                    // Ignoring errors from the feedbacks to not cause whole system shutdown by a single side-effect.
                    //
                    // RxSwift (Observable<Value>) doesn't have Type constraint for errors like:
                    // - ReactiveSwift (Signal<Value, Error>) or
                    // - Combine (Publisher<Output, Failure>)
                    // so it's very easy to miss an error from any Observable without any compile-time errors,
                    // and it's too dangerous to rely on human to take care of it.
                    .catch({ _ in .empty() })
            }
            return Observable<Event>.merge(outputs)
                // This is protection from accidental ignoring of scheduler so
                // reentracy errors can be avoided
                .observe(on: CurrentThreadScheduler.instance)
                .scan(into: (initial, nil), accumulator: { (acc: inout Input, event: Event) in
                    reduce(&acc.state, event)
                    acc.event = event
                })
                .do(onNext: { output in
                    state.onNext(output.state)
                    output.event.map(events.onNext)
                }, onSubscribed: {
                    state.onNext(initial)
                })
                .subscribe(on: scheduler)
                .observe(on: scheduler)
        }
        .observe(on: scheduler)
        .bind(onNext: { [weak self] output in
            stateRelay.accept(output.state)
            WhimCore.zip(self?.eventsRelay, output.event).map { $0.accept($1) }
        })
        .disposed(by: disposeBag)
    }

    public func asObservable() -> Observable<State> {
        state.asObservable()
    }
}

public extension FeedbackSystem {
    // TODO: check issue when feedback immediately pushes an event synchronously, which causes state change in reducer, however we don't see new state here yet even though we receive new event
    //
    // i.e.
    // - return .just(event) from a feedback
    // - change state for this event in reducer
    // - react to this event in routes inside any store - state is still old
    //
    // a simple workaround is to return an event on a scheduler which is used to create feedback system,
    // i.e. return .just(event, scheduler)
    var eventsWithState: Observable<(event: Event, state: State)> {
        events.withLatestFrom(state, resultSelector: { (event: $0, state: $1) })
    }
}

// MARK: - Utils

fileprivate extension ImmediateSchedulerType {
    var async: ImmediateSchedulerType {
        // This is a hack because of reentrancy. We need to make sure events are being sent async.
        // In case MainScheduler is being used MainScheduler.asyncInstance is used to make sure state is modified async.
        // If there is some unknown scheduler instance (like TestScheduler), just use it.
        return (self as? MainScheduler).map { _ in MainScheduler.asyncInstance } ?? self
    }
}
