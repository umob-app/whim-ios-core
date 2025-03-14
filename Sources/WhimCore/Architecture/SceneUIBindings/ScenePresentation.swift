import UIKit
import RxSwift

/// An abstract interface for the UI part of the scene.
///
/// It implies following data-driven design and unidirectional flow by providing simple IO interface.
/// You dispatch actions as an output and receive state updates as an input.
/// 
/// Data-driven means that the only way UI will update is when state changes.
/// And this state is the only source of truth for the UI.
/// It's up to UI to diff state changes if any performance optimizations needed.
///
/// Similar approach is currently the most popular way to go in the latest frontend technologies including SwiftUI.
/// UI component can be developed in total isolation from its BLL part, as it only relies on its own state.
/// It can be tested without the need to setup app environment and preferrable conditions for the business logic to work,
/// just call `render` with mock data and see how it looks like - can't be easier.
public protocol ScenePresentation: AnyObject {
    associatedtype State
    associatedtype Action

    typealias Dispatch = (Action) -> Void

    var output: Dispatch? { get set }

    func render(state: State)
}

public extension ScenePresentation {
    func dispatch(_ action: Action) {
        output?(action)
    }
}

/// Any UIViewController with `ScenePresentation` interface.
public typealias ScenePresentationViewController = UIViewController & ScenePresentation

public extension Reactive where Base: UIViewController {
    /// Sends `true` per `viewWillAppear` and `false` per `viewWillDisappear` lifecycle events.
    ///
    /// Will deliver events asynchronously on the Main scheduler.
    ///
    /// The main reason for asynchronous delivery is asynchronous nature of FeedbackLoop.
    /// If delivered synchronously, event might come before FeedbackLoop System is fully setup and thus might be missed.
    /// Once FeedbackLoop is refactored to synchronously process events, this constraint will be removed.
    ///
    /// Used mostly to make sure that map handler (being one of the multipart screen componenets)
    /// requests and relinquishes control over the shared map at a correct time.
    var isActive: Observable<Bool> {
        Observable
            .merge(viewWillAppear.map { _ in true }, viewWillDisappear.map { _ in false })
            .observe(on: MainScheduler.asyncInstance)
    }
}
