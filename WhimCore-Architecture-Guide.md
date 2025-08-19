# WhimCore Architecture Usage Guide

A comprehensive guide to using the WhimCore Feedback Loop System for building reactive, unidirectional iOS applications.

## Table of Contents

1. [Overview](#overview)
2. [Core Concepts](#core-concepts)
3. [Building Your First Service](#building-your-first-service)
4. [Creating Stores for UI](#creating-stores-for-ui)
5. [Working with State](#working-with-state)
6. [Feedback Patterns](#feedback-patterns)
7. [Testing](#testing)
8. [Best Practices](#best-practices)

## Overview

WhimCore implements a unidirectional reactive architecture based on the Feedback Loop pattern. It provides a structured approach to managing state, business logic, and side effects in iOS applications.

### Key Benefits

- **Predictable**: Unidirectional data flow makes state changes predictable
- **Testable**: Pure reducers and isolated side effects make testing straightforward
- **Modular**: Can be used at any level (service, screen, or component)
- **Reactive**: Built on RxSwift for reactive programming patterns

## Core Concepts

### The Feedback Loop

```
                             New State
            ┌──────────────────────────────────────────────────┐
            │  ┌───────────────Event─────────┐                 │
            │  │                             │                 │
            ▼  ▼                             │                 │
Initial  ┌───────┐         ┌─────────────┐    │    ┌─────────┐  │
──State─▶│ State │────────▶│   Feedback  │────┴───▶│ Reducer │──┘
         └───────┘  State  └─────────────┘  Event  └─────────┘
                      +
                Optional Event
```

### Components

- **State**: Immutable data representing the current system state
- **Event**: Actions that have occurred and trigger state changes
- **Reducer**: Pure functions that update state based on events
- **Feedback**: Side effects triggered by state changes or events

## Building Your First Service

Let's build a simple authentication service to demonstrate the architecture.

### 1. Define State, Actions, and Events

```swift
import WhimCore
import RxSwift
import RxRelay

extension AuthService {
    // Define all possible states
    enum State: Equatable {
        case idle
        case authenticating(credentials: Credentials)
        case authenticated(token: String)
        case failed(error: String)
        
        static let initial: State = .idle
    }
    
    // Define user actions
    enum Action {
        case login(username: String, password: String)
        case logout
        case retryLogin
    }
    
    // Define events (including both actions and async results)
    enum Event {
        case action(Action)
        case authenticationResult(Result<String, AuthError>)
        case userDidLogout
    }
}
```

### 2. Create the Reducer

Reducers are pure functions that handle state transitions:

```swift
extension AuthService.State {
    static func reduce(state: inout AuthService.State, event: AuthService.Event) {
        switch event {
        case let .action(.login(username, password)):
            let credentials = Credentials(username: username, password: password)
            state = .authenticating(credentials: credentials)
            
        case .action(.logout):
            state = .idle
            
        case .action(.retryLogin):
            if case let .failed(_) = state {
                // Extract previous credentials for retry logic if needed
                state = .idle
            }
            
        case let .authenticationResult(.success(token)):
            state = .authenticated(token: token)
            
        case let .authenticationResult(.failure(error)):
            state = .failed(error: error.localizedDescription)
            
        case .userDidLogout:
            state = .idle
        }
    }
}
```

### 3. Create the Service

```swift
typealias AuthServing = AbstractService<AuthService.State, AuthService.Action>

final class AuthService: AuthServing {
    private let system: FeedbackSystem<State, Event>
    private let actions = PublishRelay<Action>()
    
    override var state: ObservableProperty<State> {
        system.state
    }
    
    init(
        scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .userInitiated, internalSerialQueueName: "com.app.AuthService"),
        apiService: APIService
    ) {
        system = FeedbackSystem(
            initial: .initial,
            scheduler: scheduler,
            reduce: State.reduce,
            feedbacks: [
                // Convert actions to events
                .just(effects: actions.map(Event.action)),
                
                // Handle authentication when state changes to authenticating
                Self.performAuthentication(apiService: apiService),
                
                // Listen to external logout events
                Self.listenForLogoutNotifications()
            ]
        )
    }
    
    override func dispatch(_ action: Action) {
        actions.accept(action)
    }
}
```

### 4. Define Feedbacks

Feedbacks handle side effects:

```swift
fileprivate extension AuthService {
    // Perform authentication when state becomes 'authenticating'
    static func performAuthentication(apiService: APIService) -> Feedback<State, Event> {
        .lensingSkippingRepeated(state: \.authenticatingCredentials) { credentials in
            apiService.authenticate(credentials: credentials)
                .map { token in Event.authenticationResult(.success(token)) }
                .catch { error in .just(Event.authenticationResult(.failure(error))) }
        }
    }
    
    // Listen for external logout notifications
    static func listenForLogoutNotifications() -> Feedback<State, Event> {
        .just(effects:
            NotificationCenter.default.rx
                .notification(.userDidLogout)
                .map { _ in Event.userDidLogout }
        )
    }
}

// Helper computed properties for state introspection
extension AuthService.State {
    var authenticatingCredentials: Credentials? {
        guard case let .authenticating(credentials) = self else { return nil }
        return credentials
    }
    
    var isAuthenticated: Bool {
        guard case .authenticated = self else { return false }
        return true
    }
    
    var isLoading: Bool {
        guard case .authenticating = self else { return false }
        return true
    }
}
```

## Creating Stores for UI

For UI components, create stores that handle screen-specific logic and navigation:

```swift
final class LoginStore: WhimSceneStore {
    private let system: FeedbackSystem<State, Event>
    private let actions = PublishRelay<Action>()
    
    struct State: Equatable {
        var username: String = ""
        var password: String = ""
        var isLoading: Bool = false
        var errorMessage: String? = nil
        var isLoginButtonEnabled: Bool = false
        
        static let initial = State()
    }
    
    enum Action {
        case usernameChanged(String)
        case passwordChanged(String)
        case loginTapped
        case dismissError
    }
    
    enum Event {
        case action(Action)
        case authStateChanged(AuthService.State)
    }
    
    var state: Observable<State> { system.asObservable() }
    
    // Navigation routes
    var routes: Observable<Route> {
        system.eventsWithState.compactMap { event, state in
            switch event {
            case .authStateChanged(.authenticated):
                return .navigateToHome
            default:
                return nil
            }
        }
    }
    
    init(authService: AuthServing) {
        system = FeedbackSystem(
            initial: .initial,
            scheduler: MainScheduler.instance,
            reduce: State.reduce,
            feedbacks: [
                .just(effects: actions.map(Event.action)),
                Self.observeAuthState(authService: authService),
                Self.performLogin(authService: authService)
            ]
        )
    }
    
    func dispatch(_ action: Action) {
        actions.accept(action)
    }
}

extension LoginStore {
    enum Route {
        case navigateToHome
        case showError(String)
    }
}
```

## Working with State

### State Design Principles

1. **Use Enums for Finite States**: Model your state as a finite state machine when possible

```swift
enum LoadingState<T: Equatable>: Equatable {
    case idle
    case loading
    case loaded(T)
    case failed(Error)
}
```

2. **Make States Descriptive**: Include enough information to drive business logic

```swift
enum NetworkState {
    case offline
    case connecting
    case connected(quality: NetworkQuality)
    case reconnecting(attempt: Int, maxAttempts: Int)
}
```

3. **Use Computed Properties**: Add convenience properties for state introspection

```swift
extension MyState {
    var isLoading: Bool {
        switch self {
        case .loading, .reconnecting: return true
        default: return false
        }
    }
    
    var canRetry: Bool {
        guard case let .reconnecting(attempt, maxAttempts) = self else { return false }
        return attempt < maxAttempts
    }
}
```

## Feedback Patterns

### 1. State-Driven Effects

Trigger effects when state changes to specific values:

```swift
// Trigger effect when state becomes 'loading'
.whenBecomesTrue(state: \.isLoading) { state in
    apiService.fetchData()
        .map(Event.dataLoaded)
        .catch { .just(Event.dataFailed($0)) }
}
```

### 2. Event-Driven Effects

React to specific events:

```swift
// React to retry events
.extracting(payload: { event -> Void? in
    guard case .action(.retry) = event else { return nil }
    return ()
}) { _ in
    apiService.retryOperation()
        .map(Event.retryResult)
}
```

### 3. Continuous Effects

Effects that run continuously:

```swift
// Monitor network connectivity
.just(effects:
    networkMonitor.isConnected
        .map(Event.networkStatusChanged)
)
```

### 4. Imperative Effects

For complex side effects that need imperative control:

```swift
.imperative { dispatch in
    return { state, event in
        if case .action(.complexOperation) = event {
            // Perform complex async work
            complexService.performWork { result in
                dispatch(.workCompleted(result))
            }
        }
    }
}
```

## Testing

### Testing Reducers

Test reducers as pure functions:

```swift
func testLoginReducer() {
    // Given
    var state = AuthService.State.initial
    let event = AuthService.Event.action(.login(username: "user", password: "pass"))
    
    // When
    AuthService.State.reduce(state: &state, event: event)
    
    // Then
    expect(state).to(equal(.authenticating(credentials: Credentials(username: "user", password: "pass"))))
}
```

### Testing Complete Systems

Use `TestScheduler` for testing async behavior:

```swift
func testAuthenticationFlow() {
    // Given
    let scheduler = TestScheduler(initialClock: 0)
    let mockAPI = MockAPIService()
    let service = AuthService(scheduler: scheduler, apiService: mockAPI)
    
    // When
    service.dispatch(.login(username: "user", password: "pass"))
    scheduler.advanceTo(10)
    mockAPI.completeAuthentication(with: "token")
    scheduler.advanceTo(20)
    
    // Then
    expect(service.state.value).to(equal(.authenticated(token: "token")))
}
```

### Testing UI Stores

```swift
func testLoginStore() {
    // Given
    let authService = MockAuthService()
    let store = LoginStore(authService: authService)
    let routes = scheduler.createObserver(LoginStore.Route.self)
    
    store.routes.bind(to: routes).disposed(by: disposeBag)
    
    // When
    store.dispatch(.loginTapped)
    authService.simulateSuccessfulLogin()
    scheduler.advanceTo(10)
    
    // Then
    expect(routes.events).to(equal([.next(10, .navigateToHome)]))
}
```

## Best Practices

### 1. Keep Reducers Pure
- No side effects in reducers
- Only synchronous state updates
- Deterministic and testable

### 2. Model State as State Machines
- Use enums for finite states
- Include all necessary data in state
- Make invalid states unrepresentable

### 3. Use Appropriate Feedback Types
- `lensingSkippingRepeated` for most state-driven effects
- `whenBecomesTrue` for boolean state triggers
- `imperative` only when necessary

### 4. Handle Errors Gracefully
```swift
.lensingSkippingRepeated(state: \.needsData) { _ in
    apiService.fetchData()
        .map(Event.dataLoaded)
        .catch { error in 
            .just(Event.dataFailed(error))
        }
}
```

### 5. Use Service Locator Pattern
```swift
struct ServiceLocator {
    let authService: AuthServing
    let dataService: DataServing
    let locationService: LocationServing
}
```

### 6. Separate Concerns
- Services handle business logic and data
- Stores handle UI state and navigation
- View controllers handle UI updates only

### 7. Use Typed Routes for Navigation
```swift
enum AppRoute {
    case login
    case home
    case profile(userId: String)
    case settings
}
```

This architecture provides a robust, testable, and maintainable foundation for iOS applications. The unidirectional data flow makes state changes predictable, while the reactive nature enables elegant handling of asynchronous operations.