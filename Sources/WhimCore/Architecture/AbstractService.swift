/// The intention of this class is to simplify unit-testing and reduce boilerplate.
///
/// Motivation:
///   In order to unit-test code, that depends on the other code with some heavy logic that can take time to perform,
///   you'd need a fake dependency with some dummy logic to satisfy that unit-test, so that it runs fast.
///   And in order to use fake dependency in unit-tests, while using real implementation in production code,
///   you'd need to create a common interface for both of them.
///
/// Solution:
///   Creating an abstract class, that in theory should satisfy all needs for V2 unidirectional services.
///   Having a method to dispatch actions as its input and observable state as its output.
///   Creating a single abstract interface to describe all V2 services might seem a little too impulsive,
///   however we can try it out and see how far we can go with this solution.
///   If we don't like it, it will cost us nothing to get rid of it and use any alternative solution.
///   One if its major downsides is that once you inherit from one class, you can inherit from another.
///
/// Alternatives:
///   - First thing that comes to mind is to have a separate protocol for every implementation/fake pair.
///     However, creating a protocol for every single service that we need to fake while testing,
///     with very similar interfaces looks like boilerplate code that might seem a bit overwhelming to support.
///     And yet it's a simple and flexible solution, which can be solved by generating it with template, as it most likely won't change.
///   - Second option is to create an abstract protocol, so that any service or any of their fakes could conform to,
///     as its interface is most likely going to be the same (observe state and dispatch action).
///     However protocols with associated types need extra effort like type erasure thunks to avoid hassle while using them in swift.
///
/// Even though I personally try to avoid inheritance, idea of abstract class suits well here to solve both:
/// flexibility to swap production and fake implementations for unit-testing,
/// and remove extra boilerplate of having additional protocol for every V2 service with common interface.
///
/// To simplify usage of such abstract class, we can create typealias for every service.
/// It will actually encapsulate that we're using this class,
/// so that if we decide to move to an alternative approach, no-one will be affected by this.
/// And it will allow us to not specify generic arguments everytime.
///
/// ```
/// typealias AuthServing = AbstractService<AuthService.State, AuthService.Action>
///
/// final class AuthService: AuthServing {
///   struct State { ... }
///   enum Action { ... }
///
///   override state: Observable<State> { ... }
///
///   override dispatch(_ action: Action) { ... }
/// }
///
/// final class AuthServiceFake: AuthServing {
///   override state: Observable<State> { ... }
///
///   override dispatch(_ action: Action) { ... }
/// }
/// ```
///
/// And we can even extend concrete alias with more functionality as we would do with protocol extensions,
/// that will be visible both to production implementation and a fake one.
///
/// ```
/// extension AuthServing {
///   var subState: SubState { state.map(\.subState) }
/// }
/// ```

open class AbstractService<State, Action> {
    public init() {}

    open var state: ObservableProperty<State> {
        fatalError("You need to provide an implementation.")
    }

    open func dispatch(_ action: Action) {
        fatalError("You need to provide an implementation.")
    }
}
