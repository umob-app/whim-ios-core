# 🏛 WhimCore iOS Architecture

Agenda for the WhiCore architecture proposal is following:
- [Dependencies](#-dependencies)
- [Services](#%EF%B8%8F-stateful-services)
- [States](#-states)
- [Scenes](#-scenes)
- [Flows](#-flows)
- [Feedback Loop](#-feedback-loop)
- [Testing](#-testing)

Short summary and references are in the end of the proposal:
- [TL;DR](#-summary)
- [References](#-references)

We won't be able to dive deep into some points as it's still a long-term goal, but we should already start setting cornerstone for the most critical of them now.

## 🧩 Dependencies

Similar approach has been discussed at NSSpain, by Pointfree, BabylonHealth and many more. And I'm personally using this approach for the last 4 years.

### Motivation

* Poor control over dependencies at the moment, and everything is being called implicitly via singletons or static methods/properties. Which encourages writing entangled code even more, blocking us from scaling our project further.
  i.e. enourmous efforts needed to split codebase into modules to solve issues with very slow compilation (even incremental), having to compile all the code for V2 even if we don't need it.

* Enormously hard to unit-test any business logic, as all dependencies, configs and communication with real world are mixed together (sometimes even UI).

* Enormously hard to unit-test singletons if they have any dependencies that might be communicating with the real world.

* Starting to resolve this by passing dependencies explicitly won't fully solve problem of entangled code. Caller will be ought to to have all dependencies needed for callee, which will lead to a lot of boilerplate code and entangling between callers and callees.

### Benefits

* Structured approach to managing dependencies.

* Single place for whole app Environment and its setup.

* Much easier to figure out how to split project into smaller parts (and which parts actually).

* A way to unit-test code by passing mock implementations as dependencies, ability to easier simulate behaviour in different timezones, locales and on different dates.

### Implementation

As a general rule, I'd recommend to stick to constructor injection. I personally find this way to be the most effective, and the least problematic.
- It gives compile-time guarantess that dependencies will be present.
- Unlike injecting via variables, it doesn't allow changing dependencies at run-time, which allows us to avoid very unpredicatable bugs.
- It's really easy to use this way of DI as Swift automatically generates initializers for structs based on their properties.
- As for classes, Xcode can generate initializers as a part of refactoring: `right click class name > Refactor > Generate Memberwize Initializer`.

#### Environment

Define a `struct` to hold dependencies of the whole app environment.
- You can put there everything that needs to live as long as application session is running (basically singletons or anything static).
- It's also a good place to store any global configurations (which you read from plists or jsons in app bundle).
- There can be stored any means to communicate with the real world, even getting current date, locale or timezone. It might sound weird and fun in the beginning, but trust me, this approach gives a lot of benefits when unit-testing or prototyping.

```swift
struct Environment {
  var apiService: APIService
  var analytics: Analytics
  var configs: Configs

  var date: () -> Date
  var calendar: Calendar
  var timezone: Timezone
  var locale: Locale
}
```

We can choose different ways of grouping these items if needed so that it's more intuitive to find them or even pass whole group as dependency.

#### Assembly

Next, we need to setup environment somewhere. Best place is `AppDeleate` as it's a starting point of our application.
Of course we don't want to do it inside of `AppDelegate`, so let's extract it into `EnvironmentAssembly`.
Let's define a static class for this. Its sole purpose is to setup and provide us new environment. We can, of course, split creation into different parts. But in the end everything is assembled in one place.

```swift
final class EnvironmentAssembly {
  static func make() -> Environment {
    let configs = readConfigsFromBundle()

    Environment(
      apiService: AppAPIService(baseURL: configs.appAPIBaseURL),
      analytics: GoogleAnalytics(key: configs.gaKey),
      configs: configs,

      date: Date.init,
      calendar: Calendar.autoupdatingCurrent,
      timezone: Timezone.autoupdatingCurrent,
      locale: Locale.autoupdatingCurrent
    )
  }

  private static func readConfigsFromBundle() -> Configs { /* do some magic */ }
}
```

#### Service Locator

So far we have successfully separated data from logic of its creation for production app.
The last thing we need to do is to store this environment somewhere. Designing `Environment` as a singleton itself would limit us from mocking it in tests, however we do need environment to be accessed globally.
[Service locator](https://gameprogrammingpatterns.com/service-locator.html) seems like the best option here. It allows us storing environment globally as well as changing it in a runtime, which we'll need to do in unit-tests.

```swift
final class CurrentEnvironment {
  private static var environment: Environment!

  static var env: Environment { environment }

  static func setEnvironment(_ environment: Environment) {
    self.environment = environment
  }
}
```

This approach doesn't introduce any memory or performance regressions. And it doesn't require any third-party solutions or complex implementation from our side.

⚠️ **In no way it should be changed during application runtime, and it can be enforced with different tools like custom [linting](https://github.com/realm/SwiftLint) or [danger](https://github.com/danger/danger) rules.**

### Usage

While some advocate accessing current environment from any place in code, I recommend against doing this. Such approach turned out to work well in small codebases. But it starts being problematic in bigger projects and might introduce few issues we're trying to solve.
However we don't want to pass all dependncies top-down from caller to callee, as it will introduce a lot of boilerplate. To make best of both worlds, I'd recommend accessing `CurrentEnvironment` only inside Builders, which will be used to construct view-controllers or services (that will be passed as dependencies).

## ⚙️ Stateful Services

This proposal is inspired by few design approaches like [service-oriented architecture (SOA)](https://en.wikipedia.org/wiki/Service-oriented_architecture), [command-query responsibility segregation (CQRS)](https://en.wikipedia.org/wiki/Command_Query_Responsibility_Segregation) and [domain driven design (DDD)](https://en.wikipedia.org/wiki/Domain-driven_design).

Everything has a state, and state machines are everywhere in our code, whether we declare it explicitly or try to ignore this fact.
Sometimes it's fine to go without an explicitly defined state machine. But in more complex scenarios it becomes easy to get lost in logic, possible states and easy to miss edge cases. This leads to unwanted behavior when we least expect it.

The most familiar examples of such approach to an iOS developer might be: Application lifecycle, ViewController lifecycle, View draw and layout cycle.

### Motivation

* Any global state can be easily mutated by anyone from any place in the code (layer of architecture).

* Sources of truth are scattered all over the place and it's easy to mutate any state from any place in the code, thus leading to hard-to-track bugs and conditions to reproduce them.

* There're already many services in the codebase that we can turn into self-contained pieces of business logic, thus not drastically changing overall code structure and architecture.

### Benefits

* Stateful services can serve as the only source of truth holders for many domains, as well as being the only one who can correctly mutate their state by encapsulating this logic.

* Guarantees that no-one else will be able to change state bypassing actual logic behind this.

* State mutations will cause other pieces of application to react accordingly, which allows easier maintainance of correct state of the whole application.

* Clear understanding of the current state without having to rely on some secondary signs or sequence of events.

* Unidirectional approach to dealing with state will encapsulate details of implementation (sync, async, rx, operations, gcd) and will provide a unified API for everyone.
  You tell a service what you want to do, and everyone, who observes the state will get updated state as a result of the call (or not, if action can't be performed).

### Implementation

We'll continue using existing services by refactoring them one by one when we need to update them, or when they have big impact on the code we're dealing with. This way we'll be moving towards our goal and at the same not waste time by rewriting everything at once.

It's better to keep services as classes, so that we can share their instances by references. They need to have some kind of state that can be observed by others and since we're already using RxSwift, we'll use it for this purpose.

- If there's a flow consisting of multiple steps, where next step depends on the result of previous one, it may be a state machine.
- If a method's result might vary, depending on a result of some previous method's call, it may be a state machine.
- If there're well defined steps of an algorithm that is asynchronously executed or requires user interaction, it may be a state machine.

Of course, not all services should be designed this way. If you just need to call API endpoint and give back the result, you probably don't need to create any state machine, except for giving an ability to cancel it, as everything's already handled for you by URLSession.

Let's take an authentication service as example. We define it as a `class` with behavior relay wich allows us doing both - reading/writing a value and observing its changes in time.

```swift
final class AuthService {
  typealias State = Bool

  let state: BehaviorRelay<State>(value: false)
}
```

We don't want to allow others mutate its state in an arbitrary way, so we encapsulate relay and reveal only getter and an observable for the state. Use getter property to access current state at any point in time without subscribing to observable and moving into asynchronous world.

```swift
final class AuthService {
  typealias State = Bool

  var state: Observable<State> { _state.asObservable() }
  var currentState: State { _state.value }

  private let _state: BehaviorRelay<State>(value: false)
}
```

Actual logic is hidden inside method calls. They don't return any result to the caller. This way we can easily change inner implementation to any we want without affecting public API. This logic can be executed synchronously or asynchronously. We may use GCD to achieve our goal, or we might use Promises, or even Rx toolkit. Though the caller and everyone else, intereseted in state changes will only need to subscribe to observable and react accordingly.

```swift
final class AuthService {
  typealias State = Bool

  var state: Observable<State> { _state.asObservable() }
  var currentState: State { _state.value }

  private let _state: BehaviorRelay<State>(value: false)

  func login() {
    _state.accept(true)
  }

  func logout() {
    _state.accept(false)
  }
}
```

As we're always aware of the current state, we can perform validation before executing methods to check if such transition makes sense. If it doesn't, state wont change and nothing will happen. Again, no changes to the public API.

```swift
final class AuthService {
  typealias State = Bool

  var state: Observable<State> { _state.asObservable() }
  var currentState: State { _state.value }

  private let _state: BehaviorRelay<State>(value: false)

  func login() {
    guard !currentState else { return }
    _state.accept(true)
  }

  func logout() {
    guard currentState else { return }
    _state.accept(false)
  }
}
```

This is a pretty imperative way to treat state machines and perform effects, but it works.
So far, it doesn't require any additional tools except for one we're already using - Rx.
Though, we might shift our attention to [Combine](https://developer.apple.com/documentation/combine), once we deprecate iOS 12 and start introducing [SwiftUI + Combine](https://developer.apple.com/xcode/swiftui) in the future.

## 🚥 States

We've just introduced states as a part of services design and talked a bit about state machines. Let's discuss this topic in more details.

### Motivation

* Everything has its state, and it's better to have it explicitly defined, rather than relying on secondary signs.

* Poor state design leads to invalid invariants, which leads to undefined behavior and unhandled edge cases.

* Scattered and implicit state doesn't allow building generic tools and approaches around it, thus introducing more boilerplate code (more code = more bugs).

### Benefits

* Correctly using enums and structs to design state, reduces invalid invariants at compile time.

* Explicitly defined states allow building state machines which are easy to test, without needing any dependencies, effects or complex logic.

* State machines can provide top-level overview of the system, thus reducing entry threshold when reading code.

* You can even [generate diagrams](https://www.graphviz.org) out of state machine with a very little effort.

### Implementation

When designing a system, I usually start with domain model, and then with events that will cause its transformations. This way it's easy to start prototyping interface without having any implementations at all. It can be easily test-driven and no additional tooling is required, so you can design it in Playground or even on paper.

#### State

State is best represented with value types. This way it's pretty easy either to prevent its mutation, or allow it and get notified when any part of state changes. Even this doesn't require any third-party tools, we can use `didSet` hook on any ad-hoc variables we declare.

```swift
struct State {
  var counter = 0
}

let state1 = State()
state1.counter += 1 // won't even compile

var state2 = State() {
  didSet { print("State changed: \(oldValue) –> \(state2)") }
}
state2.counter += 1 // prints: "State changed: State(counter: 0) –> State(counter: 1)"
```

You'd usually use either `enum` or `struct` to design domain state model based on its properties.

You may want to choose `enum` when your state consists of different stages and different data is available during each of them, so basically when your state may change its shape.
And you may want to use `struct` when state doesn't change its shape during different stages, but just fills it with data.

❌ This is how you don't want to design your state. Compiler can't guarantee that invalid invariants won't happen. And it's hard to get a proper understanding of its intention because of ambiguous design.

```swift
struct State {
  // does empty array mean that we've loaded empty dataset or does it mean that we haven't loaded any yet?
  var items: [Item]

  // what if we have both isLoading=true and error at the same time?
  // even worse - what if we have items, error and isLoading=true, how should we treat such state?
  var isLoading: Bool
  var error: Error?
}
```

✅ This way would be better as it defines strict and clear semantics.

```swift
enum State {
  // Initial state, makes it clear that nothing happened yet, and there're no items yet
  case idle

  // Loading is in progress, notice that array of items is optional.
  // If it's nil, it means that we're loading  items for the very first time (right after `idle` state).
  // If it's not nil, then it means that we're refreshing data while keeping old one to render until we get new one.
  case loading([Item]?)

  // Loaded state is trickier, however it clearly describes what might happen.
  case loaded(Loaded)

  // Notice how we declare nested type to help us expressing clear semantics and our intention,
  // and at the same time, not polluting global namespace.
  enum Loaded {
    // this one is pretty-self explanatory :)
    case success([Item])

    // If we fail for the very first time, items will be nil.
    // If we fail after items were loaded, we'll keep them to render until new data is loaded,
    // while at the same time keeping error to show.
    case failure([Item]?, Error)
  }
}
```

Working with enums in Swift is easy and it provides intuitive and powerful pattern-matching mechanism.
However, there might be times when doing pattern-matching might feel awkward and you'd want good old `struct` way of deaing with properties.
There're well established ways to achieve this. You can create extensions with computed properties that will provide you `struct`-like interface, yet at the same time still having compile-time guarantee that no invalid state will ever happen.

```swift
extension State {
  var isLoadedSuccessfully: Bool {
    guard case .loaded(.success) = self else { return false }
    return true
  }
}
```

The most basic way is to have boolean properties that describe your state. You'll usually need them in predicates where boolean algebra is more appropriate.

```swift
if state.isLoadedSuccessfully || state.isLoading { /* ... */ }
```

You can also expose data via simple computed property. It might feel a bit overwhelming to write such extensions, but it's actually pretty fast with advanced source editor techniques and there're templates that can generate these extensions, so don't worry about this at all.

```swift
extension State {
  var items: [Item]? {
    switch self {
    case .idle: return nil
    case let .loading(items): return items
    case let .loaded(.success(items)): return items
    case let .loaded(.failure(items, _)): return items
    }
  }

  var error: Error? {
    switch self {
    case .idle: return nil
    case .loading: return nil
    case .loaded(.success): return nil
    case let .loaded(.failure(_, error)): return error
    }
  }
}
```

#### State Machines

As with states, state machines can be either defined explictily or used implicitly. In case of implicit state machines, we can just verify current state in-place and change it to the new one if it fits our logic.
Like we did in example above.

```swift
func login() {
  guard !currentState else { return }
  _state.accept(true)
}
```

This is an okay way to go if we don't have complex system. However such approach mixes state transition with other logic and effects. And if we want to unit-test such behavior we'd need to setup whole system with all the dependencies and perform all the complex flows to bring it into needed state and check its behavior when we want to change it.

In such cases it's good to have explicitly defined state machine. We won't need any 3rd party solutions for this as it's pretty simple task.
First thing we'll need to introduce is an intention to change state. Let's call it `Event`.
Second thing we'll need is a way to change state based on the events. And it's actually a simple pure function. Given current state and event to change it, we return new state.

```swift
//  There're few approaches to this:

// I. you can return nil if transition is invalid
(State, Event) -> State?

// II. you can return original state if transition is invalid
(State, Event) -> State

// III. instead of returning new or original state, you either mutate or not given `inout` state
(inout State, Event) -> Void
```

Event is usually represented as `enum` as it's easy to pattern match over it, and it can have associated values to hold any data that might be needed for transition.
We can improve our example above, by introducing `enum Event` and extending `State` by describing our transitions as a pure static function.
Let's call it `reduce` as its type looks similar to other reducing functions. We basically accumulate our state by given events.

```swift
extension AuthService {
  enum Event { case login, logout }
}

extension AuthService.State {
  static func reduce(state: AuthService.State, event: AuthService.Event) -> AuthService.State {
    switch (state, event) {
    case (true, logout): return false
    case (false, login): return true
    default: return state
    }
  }
}
```

So by just looking at `State`, `Event` and `State.reduce` function we can get a top-level understanding of what's going on here, in which states our system can be and which events can cause its mutation, without having to dive into implementation details. We can also easily unit-test this state machine without having to setup whole system, and we can prototype it in a very small environment that compiles and gives feedback very fast.

## 🎨 Scenes

### Motivation

* Currently, both, screen rendering and business logic is contained inside ViewController.

* Changing UI shouldn't always affect business logic and vice versa.

* We're planning to adopt SwiftUI shortly and transition shouldn't cause a lot of changes in the way we developed screens before.

* Prototyping and designing UI inside the project might be slower than expected due to long compilation time.

* Screens should be lightweight but at the same time we want to be able to unit-test their business logic.

### Benefits

* Splitting business logic apart from rendering logic allows us to design screens in isolations (even in playgrounds or our demo project), which can potentially increase development speed.

* Business logic can be unit-tested without binding to UIKit and its components' lifecycles.

* Data-driven UI minimizes inconsistencies between logical state and UIKit state comparing to event-driven approach.

* Properly designed state minimizes invalid invariants, thus should minimize code complexity.

* Unidirectional approach should work well with SwiftUI out of the box (Apple demonstrates it in WWDC talks).

* Unidirectional approach simplifies synchronization of state and UI.

* Same as with Services, you don't care about Store's implementation details. It can be synchronous or asynchronous, it can use GCD, operations, promises or rx. The only thing you care is how to render new state (sometimes diffing with the old state).

### Drawbacks

* Some UIKit APIs don't work well with unidirectional flow. i.e. TextField's delegate needs immediate (synchronous) answer [whether we should allow entering characters or not](https://developer.apple.com/documentation/uikit/uitextfielddelegate/1619599-textfield). Such issues are rare and aren't impossible to solve, but their solutions might feel a bit non-intuitive. This is the price we'll have to pay while moving this direction and preparing for SwiftUI (which, on the contrary, is designed with such approach in mind).

### Implementation

#### View

We've already mentioned data-driven UI and unidirectional flow few times. And now it's time to discuss what does it mean for us.
Data is everything that drives our UI. Data can be represented by state as well as by model entities.
Using this approach we can imagine our view-controller as a function from state to UI, where UI is always derived from State as a single source of truth.

```swift
(State) -> UIKit
```

By applying this to our view-controllers, they might look like this:

```swift
final class Screen: UIViewController {
  private(set) var state: State

  func render(state newState: State) {
    // diff state and newState if needed
    // render view by assigning it state properties

    // save new state as current one
    state = newState
  }
}
```

Now we should be able to fully render UI at any point in time using only given state.
With event-driven approach you get a bunch of events that you should somehow synchronize with current UI, think of their order and apply them accordingly.
Data-driven, on the contrary, requires you to update your source of truth (state) first, and then derive UI from it. Even if, by any chance, your UI gets out of sync for a moment, next update of state will cause it to redraw and will remove this glitch. With data-driven approach you don't care about order of events, the only even you have is state update. I highly recommend watching [WWDC 2019 #204](https://developer.apple.com/videos/play/wwdc2019/204/) talk to see how this approach is used in SwiftUI.

So far our view-controller looks pretty neat and doesn't have any dependencies except for the state, which is a plain data structure.
Seems like there should be someone else, who's producing the state and performs business logic. We don't know who it is yet, but we definitely need to have some ability to communicate back and tell when we want to perform some action, whether it comes straight from the user or from UIKit.

The simplest way to go is to have plain function that accepts some action.

```swift
(Action) -> Void
```

This approach is starting to look very similar to services design we discussed earlier. But now view-controller is on the other side and has "inverted" API. Instead of producing state, it receives it. Instead of receiving actions, it dispatches them. Let's add output property to our view-controller.
Even though, I strongly suggest using constructor injection, I decided to go with variable injection here, as it doesn't limit us to initiating view-controllers from xib, storyboard or without any at all. And with such design we can't mess up UI by re-assigning output or even setting it to nil in runtime.

```swift
class Screen: UIViewController {
  private(set) var state: State

  var output: ((Action) -> Void)?

  func render(state newState: State) {
    // diff state and newState if needed
    // render view by assigning it state properties

    // save new state as current one
    state = newState
  }
}
```

So far, we've introduced only one new dependency, and it's an `Action` type. Actions can be usually designed as enums because of the same reasons `Event` is usually an enum - exhaustive pattern matching and ability to add different payloads to each case.
We have fully designed our view-controller with state and actions. We don't need any business logic with its scary dependencies at all. We can test its UI by giving it any possible `State` we want. We can design it in isolation from our main project (though we might need only few UI extensions and utils). We can finally enjoy fast compilation and immediate access to this screen in playground preview or sandboxed app in simulator or on device. No need to click thousand times to find this screen in our huge app, no need for server to be working to see how it will look like, i.e. filled with data, in loading state or after failure, just pass state or sequence of states with timer and see how it renders.

Developing UI in isolation also helps you to untangle your code. This way you're not seduced by using business entities for rendering, but you're designing small and lightweight structures, driven by UI requirements. Next time you'd need to change business entities structure, you'd only have to update mapping from BLL models to UI models and in no way you'd need to mess with UI code.

#### Store

There's not much new left to tell about how we design business logic part for our view. We'll call it `Store` and it will have very similar API as our stateful services have - observable `State` as output and a method that accepts `Action` as an input. And let's nest `State` and `Action` inside `Store` for convenience.

```swift
final class Store {
  var state: Observable<State> { _state.asObservable() }
  var currentState: State { _state.value }

  private let _state: BehaviorRelay<State>(value: .idle)

  func dispatch(Action) {
    switch (currentState, action) {
    case (.idle, .load): load()
    default: break
    }
  }

  private func load() {
    _state.accept(.loading)
    // do some magic here
    _state.accept(.loaded)
  }
}

extension Store {
  enum State { case idle, loading, loaded }

  enum Action { case load }
}
```

The only difference between store and services is that services have explicit methods, while store accepts action, which represents number of methods.
Of course we could achieve same result by introducing `protocol` with bunch of methods instead of `(Action) -> Void` output. However I find it to be a better way to guarantee unidirectional approach.
It's easy to hack using protocols when tempted, as you can define methods that immeditely return results, which violates unidirectional approach. It's also easy to introduce other unwanted stuff into protocol, while a simple function with a single argument minimzes this risk. Unfortunately we can't guarantee at compile-time that `Action` won't contain functions, but we'll leave this part for PRs review :)

#### Builder

The third layer is something that needs to bind both of them together. It's very thin and is responsible for creating a view-controller instance with everything it needs to function.
Here, builder is responsinble for creating view-controller, store, binding them together and making sure to get all needed dependencies for the store. You can declare several methods inside builder if you want to create view-controller with different configuration or store.
Simplified, but not complete implementation might look like this:

```swift
enum Builder {
  static func make() -> Screen {
    let viewController = Screen()
    let store = Store()
    viewController.output = store.dispatch
    store.state
      .observe(on:MainScheduler.asyncInstance)
      .subscribe(onNext: { [weak viewController] in viewController?.render(state: $0) })

    return viewController
  }
}
```

Instead of going deep down into its complete implementation, which is, btw, included in demo app and `Templates` directory, I'd rather list requirements for the `Builder`:
- Rendering should be performed on main queue.
- No reference cycles should be established when binding view-controller with store.
- All Rx-related subscriptions must be disopsed after store dies, as it's just a big pile of reference cycles.
- Store should be retained by view-controller.
- View-controller should start receiving `render` calls only after `viewDidLoad` so that all views and outlets are loaded into memory.
- Builders are usually the only entities that can access global environment (which we've discussed in `Dependencies` part of this proposal), or create instances of other services to pass as dependencies into store.

#### Routing

The last thing I'd like to mention is routing. There's a good practice, which I'd like to propose as a general rule. It's very similar to manual memory management in Objectve-C and basically any resource ownership model.

**The one who presents view-controller, is responsible for dismissing it.**

There're pretty good reasons for this. View-controller doesn't know much about the context it is presented in. Of course, everyone who inherits from UIViewController has references to NavigationController or methods to dismiss yourself as a modal controller, pop from navigation stack and many more shortcuts, tricks and hacks to do different things. It may work fine in small projects. But things tend to change a lot and quickly in big projects. Hardcoding context knowledge inside view-controller bloats it and gives more opportunities to bugs. Especially if view-controller can be presented in different contexts like navigation stack, tabbar, modally, embeded as a child or have custom transitions.

Store is responsible for telling when the screen is ready to be dismissed. Store is a better candidate rather than view-controller for this purpose, because store is the one who conains state (single source of truth) and a busniess logic. Store can validate whether we're really ready to be dismissed, i.e. user taps back button and we have some unsaved data, in this case store will take care of validating this before actually telling that screen is ready to be dismissed.

**Routing is derived from state or action.**

Routing can be represented as an `Observable<Route>` where `Route` is most likely an enum with different cases for each route and associated values if any data needs to be passed back.
You can even put a function as associated value inside routing cases to be called-back once task is performed on another screen, and to be able to react accordingly (i.e. change state).

I'd split routing in three categories:
- Fire and forget - you don't care about its completion and it doesn't affect your state (i.e. showing message/info popup/screen).
- Wait for result - you care about its completion which might affect your state as a result (i.e. showing picker and waiting for a selected item).
- Controled by state - you fully control navigation flow within state (i.e. embeded child as a part of a complex flow).

While in the first and the second case routing can be also derived from the state, it might be overwhelming to represent it inside state. You would need to make sure that events are sent when presentation is finished, to rollback state to its previous form.
However I'd recommend to try deriving routing from state first, and if it turns out to be too much boilerplate, then turn to the other options of deriving it from action. As it will allow us to keep our system's property of having state as a single source of truth and to have a complete picture of everything what's going on. Similar approach is also heavily used in SwiftUI, so we can have better time transitioning to it.

```swift
final class Store {
  // ... original implementation

  private let actions = PublishRelay<Action>()

  let routes: Observable<Route>

  init() {
    let stateRoutes = state
      .map { state -> Route? in
        // derive Route from State or return nil if nothing should happen
      }

    let actionRoutes = actions.asObservable()
      .map { action -> Route? in
        // derive Route from Action or return nil if nothing should happen
      }

    routes = Observable.merge(stateRoutes, actionRoutes).ignoreNil()
  }

  // ... original implementation
}

extension Store {
  enum Route { case dismiss }
}
```

We're creating screens using builders. It makes sense to extend our builder logic and provide a way to react to its routes from the outside, so that a caller would have easy way to dismiss it.
There's nothing simpler than having a callback with route and a screen reference arguments. This way we have a reference to the screen we want to dismiss right inside our callback out of the box. And we don't care whether we're using `Rx`, `Combine` or other mechaincs under the hood. We are also decoupling routes from the actual view-controller which would be harder to achieve if we went on with using delegation protocol instead of callback.

```swift
enum Builder {
  static func make(router: @escaping (Screen, Store.Route) -> Void) -> Screen {
    let scene = Screen()
    let store = Store()

    // ... original implementation

    store.routes
      // redirecting it to the main queue
      .observe(on:MainScheduler.asyncInstance)
      // weakifying reference to the scene here to avoid retain cycle,
      .subscribe(onNext: { [weak scene] route in
        // but providing strong reference to avoid doing it in caller every time
        guard let scene = scene else { return }
        router(scene, route)
      })

    return scene
  }
}
```

Now on to actually using it!

```swift
let scene = Builder.make({ [weak self] scene, route in
  switch route {
  case .dismiss: self?.dismiss(scene)
  }
})
present(scene)
```

## 🌊 Flows

Of course it's crucial to touch flows and navigation topic, as we don't work with screens in isolation. Flows are everywhere whether we describe them explicitly or let them be implicitly. However, the bigger an application gets, the more complex logic it gains and the more complex scenarios appear. It's better to have an approach, or pattern, or tools to be able to operate with 'flow' abstraction.

### Motivation

* Screens are tightly coupled to one another while navigating back and forth during flows.

* It's hard to reorder screens or insert new screens in-between existing flows.

* The deeper the flow goes, the more data and dependencies you need to pass to the next screen in the flow, as they should be passed through each screen in predefined order.

One of the most popular approaches is coordinators. You would declare coordinator as a plain object (not related to UIKit) which contains logic of navigating through the flow and its current state.
And it can be easily unit-tested as it has its own state and doesn't depend on UIKit.
However there are few critical drawbacks to such an approach - it can be easily desynchronized with UIKit's own navigation state and it introduces new abstraction to implement, support and learn.

The idea is to use simple view controllers for fulfilling purpose of the flows.

### Benefits

* Easier way to support and modify flows.

* Single entity to manage each flow's logic.

* Ability to reuse flows as a single view-controller, not caring how compex they are.

* Everyone knows how to use `UIViewController` (or at least one can [RTFM](https://developer.apple.com/documentation/uikit/uiviewcontroller)).

* We don't care whether it is just a single view-controller or a complex flow with its own navigation, we still treat is as `UIViewController`.

* No need for the new architecture solutions or new abstractions to support and learn.

* No need to fight with UIKit or sync with its navigation state, it handles all the heavy-lifting for us.

* You can implement flow navigation logic inside view-controller, as well as extract it into its store as in the case with the usual scene. It allows iterative refactoring, keeping old view-controllers and flows fully compatible with the new approach.

* Whole `UIViewController` API is at our disposal including `UIResponder`.
  For example we can make use of such mechanism like [`show(_:sender:)`](https://developer.apple.com/documentation/uikit/uiviewcontroller/1621377-show) method along with [`targetViewController(forAction:sender:)`](https://developer.apple.com/documentation/uikit/uiviewcontroller/1621415-targetviewcontroller) + [`canPerformAction(_:withSender:)`](https://developer.apple.com/documentation/uikit/uiresponder/1621105-canperformaction) for simple navigation in custom stacks.

There're few ways to use view-controllers as coordinators:
- You may embed child controllers with or without custom transitions.
- You may inherit or embed navigation stack or other UIKit navigation controller (i.e. tabbar controller) and use them to move through the flow.
- Sometimes you may not even need other view-controllers to be part of the flow and instead switch views inside single view-controller.

As you see, there're plenty of ways to achieve our goal which can be treated both as advantage and disadvantage. Nevertheless it stays as encapsulated implementation detail of a single flow, while still giving us variety of choices and great flexibility. And we don't have to migrate all of our old code at once to some new approach, but keep it more or less compatible until we have a reason and resources to do it.

There're two good articles explaining how such an approach can be achieved and what are the tradeoffs, with small code examples:
- [Controller Hierarchies](https://sandofsky.com/patterns/controller-hierarchies/)
- [Going Back To The Roots](https://ilya.puchka.me/going-back-to-the-roots/)

## 🔁 Feedback Loop

### Motivation

* State management can be scattered all over the codebase.

* Setting up same system everytime we want state machine, side effects, synchronized state mutations and correct reactions to state changes can become boring, time-consuming and error-prone.

* Cyclic data dependencies.

* Reentrancy Rx issues.

### Benefits

* Structured approach to having unidirectional system with state machine, side effects and declarative way to describe when and what should be done.

* Common issues solved out of the box like reentrancy and race conditions.

* Makes it much easier to test system by having explicitly defined state machine and side effects.

* Makes it much easier to test complex time-sensitive system by running it on a single scheduler which can be replaced with `TestScheduler` from `RxTest`.

* Allows building tools to simplify unit-testing.

### Implementation

There are few 3rd party implementations, and one of them is [RxFeedback](https://github.com/NoTests/RxFeedback.swift). It's pretty small and we need only half of it, so we can even have our own implementation based on existing ones. You can see examples in the app with the new Whim flow and new Services.

The main idea is that we have
- State: describes overall system state, as we've discussed earlier.
- Event: denotes something that has already happened and is used to change state.
- Reducer: state machine that returns new state based on original state and an event, or returns original state if no transition happened. Most of business logic should be here.
- Feedbacks: feedback is a side-effect defined by a pair of two callbacks:
  - Rrequest: receives state every time it changes and returns part of its data needed to run side effect, or returns nil if no side effect needs to run.
  - Eeffect: receives part of the state returned from the first callback and returns observable of event, which will be used to change state via the state machine.

Reducer is the only one who can change state based on event and feedbacks are the only one who can initiate state change by sending an event. So we're pretty much in a loop.

```
                                      New State
                ┌────────────────────────Or──────────────────────────┐
                │                  Original State                    │
                ▼                                                    │
┌┐ Initial  ┌───────┐          ┌─────────────┐          ┌─────────┐  │
││──State──▶│ State │──State──▶│   Feedback  │──Event──▶│ Reducer │──┘
└┘          └───────┘          └─────────────┘          └─────────┘
```

If it seems unclear at first, don't worry. I will be glad to help you with it, as I've spent last three years slowly going towards similar one.
Please note, that this is the approach that we would eventually come up with sooner or later as it adds nothing new but just organizes our system.

This approach is inspired by [control theory](https://en.wikipedia.org/wiki/Control_theory) (this is where "feedback" comes from) and [Moore state machine](https://en.wikipedia.org/wiki/Moore_machine).

I highly recommend watching and reading these two talks, as they describe both motivation and implementation of this approach:
- [RxFeedback](https://academy.realm.io/posts/try-swift-nyc-2017-krunoslav-zaher-modern-rxswift-architectures)
- [ReactiveFeedback](https://ilya.puchka.me/implementing-features-with-reactivefeedback)

### NOTE

This tool doesn't affect any public interfaces. The approach is encapsulated as implementation details and will not affect any existing or future architecture. And this is only a small util that should help us organizing state and business logic, and should give us more benefits when unit-testing.

## 🐞 Testing

Testing with feedback-system is pretty easy. There's `StoreVerification` utility which helps to setup any service or store based on feedback-system with test-scheduler.
It follows [given-when-then](https://martinfowler.com/bliki/GivenWhenThen.html) or [arrange-act-assert](https://wiki.c2.com/?ArrangeActAssert) pattern for describing unit-test.

First, you need to setup a service you whish to test within `given` block by injecting a provided test-scheduler into your service and returning service with its observable state.
```swift
let sut = StoreVerification<AuthService, AuthService.State>(given: { scheduler in
  let store = AuthService(scheduler: scheduler, service: WikiNetworkingMock())
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
    store.loginAsGuest()
    // finish by advancing scheduler so that last step is executed
    scheduler.advanceBy(10)
  },
  then: { events in
    // RxTest provides custom assertions
    // to easily verify events with actual states
    // when other info (their time) not needed
    XCTAssertRecordedElements(events, [
        .idle,
        .login(.succeeded(token: nil, user: .guest))
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

## 🔖 Summary

### Dependencies

- `Environment container` stores dependencies
- `Environment service-locator` stores current environment container
- `Environment assembly` creates environment

### Stateful Service

- Responsible for a single domain, thus domain-driven
- Self-contained
- Single source of truth for their domain
- Implements correct state machine
- Unidirectional
- Unit-tested

### State

- Normalized
- Only data, no behavior
- Best represented with `struct` or `enum`
- Can be easily equatable or (de-)serializable

### State Machine

- `(State, Event) -> State`
- Pure function (no side effects)
- Relies on previous state and event **only**
- Unit-tested

### Scene

- Domain-driven
- Unidirectional
- Submits to resource ownership model - **the one who presents the scene is responsible for dismissing it**
- Consists of:
  - View
    - UI is derived from state `(State) -> UI`
    - UI can dispatch actions to the store `(Action) -> Void`
    - No business logic
    - Doesn't dismiss itself
  - Store
    - Keeps observable state
    - Performs business logic
    - Updates state in response to incoming actions or inner events
    - May incorporate state machine to manage state updates
  - Builder
    - Creates scene for different scenarios and configurations
    - Binds view with the store
    - Can access global environment to inject needed dependencies into the store
    - Makes sure updates are coming on a correct queue in correct time and there're no reference cycles or unreleased resources left
  - Routing
    - Derived from state `(State) -> Route?`
    - Derived from action `(Action) -> Route?`
    - Handled inside store
    - Exposed to those who present the scene
    - May contain callbacks to return data to the caller

### Flows

- Make use of `UIKit`, don't fight it
- `UIViewController` as coordinator
- Embed child controllers, inherit from `UIKit` navigation controllers or embed them and go through the flow using them

### Feedback Loop

- Domain-driven
- Unidirectional
- State machine is a pure function `(State, Event) -> State`
- Effects happen as a consequence of a state change and produce events as a result `(Observable<State>) -> Observable<Event>`
- Each system runs on its own serial scheduler
- State machine is easy to unit-test as a pure function, system is easy to unit-test with a single `TestScheduler` from `RxTest` and our cutom utils

### Testing

- Follow given-when-then or arrange-act-assert pattern
- Use our `StoreVerification` util for testing feedback-system-based services and stores
- Use `TestScheduler` from `RxTest` for easy testing time-sensitive and asynchronous logic
- Use our custom `XCTest` and `Nimble` matchers for easier assertion of recorded state updates

## 🔗 References

- How To Control The World
  * [NSSPain Talk](https://vimeo.com/291588126)
  * Pointfree episodes [16](https://www.pointfree.co/episodes/ep16-dependency-injection-made-easy) and [18](https://www.pointfree.co/episodes/ep18-dependency-injection-made-comfortable)
  * [BabylonHealth Example](https://github.com/babylonhealth/ios-playbook/blob/master/Cookbook/Proposals/ControlTheWorld.md)
- [Algebraic Data Types](https://www.pointfree.co/episodes/ep4-algebraic-data-types)
- [Playground Driven Development](https://www.pointfree.co/episodes/ep21-playground-driven-development)
- [Controller Hierarchies](https://sandofsky.com/patterns/controller-hierarchies/)
- [Going Back To The Roots](https://ilya.puchka.me/going-back-to-the-roots/)
- [Elm](https://guide.elm-lang.org/architecture/), [Redux](https://redux.js.org/introduction/motivation), [Flux](http://blog.benjamin-encz.de/post/real-world-flux-ios/)
- [RxFeedback](https://academy.realm.io/posts/try-swift-nyc-2017-krunoslav-zaher-modern-rxswift-architectures/)
- [ReactiveFeedback](https://ilya.puchka.me/implementing-features-with-reactivefeedback/)
- [Testing with Rx](https://www.raywenderlich.com/7408-testing-your-rxswift-code)
- [RxSwift vs Combine cheatsheet](https://github.com/CombineCommunity/rxswift-to-combine-cheatsheet)
- [Protocol and Value Oriented Programming in UIKit Apps](https://developer.apple.com/videos/play/wwdc2016/419)
- SwiftUI:
  * [Introducing SwiftUI: Building Your First App](https://developer.apple.com/videos/play/wwdc2019/204)
  * [SwiftUI Essentials](https://developer.apple.com/videos/play/wwdc2019/216)
  * [Data Flow Through SwiftUI](https://developer.apple.com/videos/play/wwdc2019/226)
  * [Integrating SwiftUI](https://developer.apple.com/videos/play/wwdc2019/231)
  * Pointfree episodes [65-79](https://www.pointfree.co/episodes/)
