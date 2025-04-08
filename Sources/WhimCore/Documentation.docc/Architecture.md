# 🏛️ Architecture

A unidirectional Fedback Loop System that allows describing business logic driven by State.

## Overview

In this article we're talking about unidirectional architectural approach to structuring state, business logic and side effects.

---

### ⚙️ Feedback System

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

---

### 🚦 State

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

---

### 🧑‍🔬 Testing

Testing is already quite straightforward if you keep your business logic inside reducers as much as possible. You can test any state change by passing initial state with an event and comparing it to the resulting state.
```swift
// given
var state: AuthService.State = .idle
// when
AuthService.reduce(state: &state, event: .didAuthenticate(.success(token)))
// then
XCTAssertEqual(state, .authenticated(token))
```

However you can still test full system including asynchronous feedbacks with ease.
Check `WhimCoreTest` documentation for details.

---

### 🔗 References

- [Algebraic Data Types](https://www.pointfree.co/episodes/ep4-algebraic-data-types)
- [Elm](https://guide.elm-lang.org/architecture/), [Redux](https://redux.js.org/introduction/motivation), [Flux](http://blog.benjamin-encz.de/post/real-world-flux-ios/)
- [RxFeedback](https://academy.realm.io/posts/try-swift-nyc-2017-krunoslav-zaher-modern-rxswift-architectures/)
- [ReactiveFeedback](https://ilya.puchka.me/implementing-features-with-reactivefeedback/)
- [ReactiveCocoa/Loop](https://github.com/ReactiveCocoa/Loop)
- [Trafi/States](https://github.com/trafi/states)
- [Testing with Rx](https://www.raywenderlich.com/7408-testing-your-rxswift-code)
- [Protocol and Value Oriented Programming in UIKit Apps](https://developer.apple.com/videos/play/wwdc2016/419)

## Topics

- ``Feedback``
- ``FeedbackSystem``
- ``AbstractService``
- ``ObservableProperty``
