import RxSwift

/// An abstract interface for the BLL part of the scene.
///
/// It implies following data-driven design and unidirectional flow by providing simple IO interface.
/// You dispatch actions as an input and observe state updates as an output.
/// Data-driven means that the only way UI will update is when state changes.
/// And this state is the only source of truth for the UI.
/// It's up to UI to diff state changes if any performance optimizations needed.
///
/// This interface doesn't care how exactly you implement it.
/// You can use existing `FeedbackLoop` with a serial scheduler to separate pure logic from side effects and ease unit-testing.
/// Or you can just write any kind of imperative code if feel more comfortable with it.
///
/// Routes can be treated as a callback to notify owner (flow coordinator or anyone else who presents this scene)
/// that you finished your task or want to proceed to another scene.
public protocol SceneStore: AnyObject {
    associatedtype State
    associatedtype Action
    associatedtype Route

    var state: Observable<State> { get }
    var routes: Observable<Route> { get }

    func dispatch(_ action: Action)
}

public extension SceneStore where Route == Never {
    var routes: Observable<Route> {
        return Observable.never()
    }
}
