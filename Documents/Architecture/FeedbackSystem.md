# 🏛 WhimCore Architecture

## ⚙ Feedback System

Architecture tooling is based around a Feedback Loop idea.
It's a structured approach to having a unidirectional system with a state machine, side effects and a declarative way of describing when and what should be done.

The main components are:
- **State**: an overall system state.
- **Event**: something that has already happened and is used to change state.
- **Reducer**: a place where the state is changed based on the event, basically a business logic.
- **Feedback**: a side effect being triggered by a state change in most cases, or by an event when it's more suitable.
  A feedback consists of two main components:
  - **Input** function - being triggered when state changes (or event comes in). It is a transformation function where we decide whether certain state change should trigger an Effect.
  - **Effect** function - being triggered based on Input's decision, and as a result it produces an Event which will go back into Reducer to change State. Here we execute actual side effects, like a network or database request, analytics logging, etc. It should not containt business logic as it's the most difficult place to test compared to simple and linear Reducer function.

```
                                 New State
                ┌──────────────────────────────────────────────────┐
                │  ┌───────────────Event─────────┐                 │
                │  │                             │                 │
                ▼  ▼                             │                 │
┌┐ Initial  ┌───────┐         ┌─────────────┐    │    ┌─────────┐  │
││──State──▶│ State │────────▶│   Feedback  │────┴───▶│ Reducer │──┘
└┘          └───────┘  State  └─────────────┘  Event  └─────────┘
                         +
                   Optional Event
```

When Effect is driven by a State change it becomes more declarative and easier to follow. Changing state is as simple as changing a single value - you don't need to go into complicated asynchronous operations, and it doesn't matter what caused a state to change, in the end there's an isolated Effect that will trigger that complicated asynchronous operation based on a State change.

This tool doesn't need to be application-wide like Redux or TCA, and can be used in isolation for just a single service or a single screen.
And interface of such a service or a screen store won't expose any details about it to the outside, so it can be easily refactored and changed over time.
```swift
final class AuthService {
  var state: Observable<State> { ... }

  func dispatch(_ action: Action) { ... }
}
```

When it comes to implementation, you simply create a FeedbackSystem with Reducer and a list of Feedbacks as main components.
Notice that we're passing a scheduler - this is important part of the Feedback System - since it's a unidirectional flow, the order of execution should always be predictable, hence the scheduler should be serial. The reason to pass it as an argument is for unit testing purposes - RxTest provides a very powerful utility called TestScheduler, which allows testing any asynchronous logic inside of a Feedback System as a linear set of events and control its virtual time in a serial fashion.
```swift
extension AuthService {
  struct State {
    static let initial: State = .init()
  }

  enum Action {
  }

  enum Event {
    case action(Action)
  }
}

extension AuthService.State {
  static func reduce(state: inout AuthService.State, event: AuthService.Event) {
    switch event {
    }
  }
}

final class AuthService {
  private let system: FeedbackSystem<State, Event>
  private let actions = PublishRelay<Action>()

  var state: ObservableProperty<State> { system.state }

  init(
    scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .userInitiated, internalSerialQueueName: "...")
  ) {
    system = FeedbackSystem(
      initial: State.initial,
      scheduler: scheduler,
      reduce: State.reduce,
      feedbacks: [
        Feedback.just(effects: actions.map(Event.action))
      ]
    )
  }

  override func dispatch(_ action: Action) {
    actions.accept(action)
  }
}
```

## 🚦 State

Let's talk about State organization.
There's a lot of material on how to organize your State in a safe way to avoid invalid invariants and gain compiler safety, so we won't go deep into that here.
However there's more to designing a robust State that describes not just a snapshot of data, but also your business logic behavior.

i.e. when describing a user authentication state, one could go for describing finite states like this:
```swift
enum AuthState {
  case unauthenticated(Error?)
  case authenticated(Token)
}
```
But here we're missing a lot of details which are scattered over other parts of the program and usually are tiresome to collect together
- was it unauthenticated after trying to authenticate, or is it just an initial state?
- is it trying to authenticate right now or not?

In case we answer these questions here, we can not only have more information about what's actually happening, but we can actually drive business logic through this state treating it as a Moore state machine.
```swift
enum AuthState {
  case idle
  case unauthenticated(Error?)
  case authenticating(Credentials)
  case authenticated(Token)
}
```
So whenever you receive an action to authenticate a user, all you need to do is to change a state to a respective one.
And why not create other state transitions for their respective events and actions since we are here?
```swift
extension AuthService {
  enum Action {
    case authenticate(Credentials)
  }

  enum Event {
    case action(Action)
    case didAuthenticate(Result<Token, Error>)
  }
}
extension AuthService.State {
  static func reduce(state: inout AuthService.State, event: AuthService.Event) {
    switch event {
      case let .action(.authenticate(credentials)):
        state = .authenticating(credentials)

      case let .didAuthenticate(.success(token)):
        state = .authenticated(token)

      case let .didAuthenticate(.failure(error)):
        state = .unauthenticated(error)
    }
  }
}
```
This way we can describe our business logic by operating State and Events to mutate it, without complicating it with asynchronous operations.
Now finally we can implement a side effect that will perform authentication when state changes.
```swift
extension AuthService {
  static func performAuthentication() -> Feedback<State, Event> {
    Feedback.lensingSkippingRepeated(state: \.authenticatingCredentials, effects: { creds in
      apiService.authenticate(with: creds).map(Event.didAuthenticate)
    })
  }
}
extension AuthService.State {
  var authenticatingCredentials: Credentials? {
    guard case let .authenticating(credentials) else {
      return nil
    }
    return credentials
  }
}
```
and add it to the feedbacks list when initializing FeedbackSystem
```swift
system = FeedbackSystem(
  ...
  feedbacks: [
    Feedback.just(effects: actions.map(Event.action)),
    Self.performAuthentication(),
  ]
)
```

## 🐞 Testing

Testing with feedback-system is pretty easy. There's `StoreVerification` utility which helps to setup any service or store based on feedback-system with test-scheduler.
It follows [given-when-then](https://martinfowler.com/bliki/GivenWhenThen.html) or [arrange-act-assert](https://wiki.c2.com/?ArrangeActAssert) pattern for describing unit-test.

First, you need to setup a service you whish to test within `given` block by injecting a provided test-scheduler into your service and returning service with its observable state.
```swift
let sut = StoreVerification<AuthService, AuthService.State>(given: { scheduler in
  let store = AuthService(scheduler: scheduler, service: APIServiceMock())
  return (store, store.state)
})
```

Second, you may call `verify` function with two blocks:
- In `when` block you run actual logic that you're willing to test
- In `then` block you run actual assertion

```swift
sut.verify(
  when: { store, scheduler in
    // you start workflow by advancing scheduler
    // so that system would start working
    scheduler.advanceBy(10)
    // and then rotate - performing work and advancing scheduler
    store.dispatch(.authenticate(credentials))
    // finish by advancing scheduler so that last step is executed
    scheduler.advanceBy(10)
  },
  then: { events in
    // RxTest provides custom assertions
    // to easily verify events with actual states
    // when other info (their time) not needed
    XCTAssertRecordedElements(events, [
      .action(.authenticate(credentials)),
      .didAuthenticate(.success(token))
    ])
  }
)
```

Notice how you always keep advancing the scheduler in the `when` block.
Test scheduler is basically a virtual scheduler and it treats time as a virtual unit. Virtual time doesn't advance by itself, thus no work is executed on a scheduler unless you explicitly advance its time.
Don't worry if it sounds confusing from a first sight. There's an amazing explanation of how it works in [Testing Your RxSwift Code](https://www.raywenderlich.com/7408-testing-your-rxswift-code#toc-anchor-006) article.
In short, you need to advance test-scheduler by a little bit, after each bit of work you want to execute. This approach scales to any bespoke flexibility in testing asynchronous code you dream up.

You receive all recorded events with state updates in `then` block. Event is basically a pair of state and virtual time point when that state was updated. There're custom `XCTest` and `Nimble` assertions, that allow you to simplify verification of recorded states.

You can call `verify` block multiple times to test different behavior, but be aware that each verification you perform on a single instance of `StoreVerification` will continue from where previous one left off, as it's using still the same service and virtual timer.
You can even split it into separate `when` or `then` calls. It might be handy in `Quick` tests, where you can have nested contexts, and each adds some behavior using `when` block.

## 🔗 References

- [Algebraic Data Types](https://www.pointfree.co/episodes/ep4-algebraic-data-types)
- [Elm](https://guide.elm-lang.org/architecture/), [Redux](https://redux.js.org/introduction/motivation), [Flux](http://blog.benjamin-encz.de/post/real-world-flux-ios/)
- [RxFeedback](https://academy.realm.io/posts/try-swift-nyc-2017-krunoslav-zaher-modern-rxswift-architectures/)
- [ReactiveFeedback](https://ilya.puchka.me/implementing-features-with-reactivefeedback/)
- [Testing with Rx](https://www.raywenderlich.com/7408-testing-your-rxswift-code)
- [Protocol and Value Oriented Programming in UIKit Apps](https://developer.apple.com/videos/play/wwdc2016/419)
