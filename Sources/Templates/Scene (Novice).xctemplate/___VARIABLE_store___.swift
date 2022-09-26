//___FILEHEADER___

import Foundation
import WhimCore
import RxSwift
import RxRelay

// MARK: - State

extension ___VARIABLE_store:identifier___ {
    // Plain data, no business logic. However it should contain everything needed to render screen.
    // It's usually a good practice to describe state with enums and/or structs, keeping it as a value type.
    // Avoid using Business or Networking Entities here. This way you'll isolate UI from those layers.
    struct State {
        static let initial: State = .init()
    }
}

// MARK: - Actions & Events

extension ___VARIABLE_store:identifier___ {
    enum Action {
        case didTapCloseButton
        // Treat actions as store inputs. They will usually come from ViewController or Tests.
    }

    enum Event {
        case action(Action)
        // Describe events that should trigger state changes.
    }
}

// MARK: - Reducer

extension ___VARIABLE_store:identifier___.State {
    // swiftlint:disable:next superfluous_disable_command cyclomatic_complexity
    static func reduce(state: inout ___VARIABLE_store:identifier___.State, event: ___VARIABLE_store:identifier___.Event) {
        // Change state here according to incoming events.
        switch event {
        case .action(.didTapCloseButton):
            break
        }
    }
}

// MARK: - Store

final class ___VARIABLE_store:identifier___: SceneStore {
    private let system: FeedbackSystem<State, Event>
    private let actions = PublishRelay<Action>()

    var state: Observable<State> {
        return system.asObservable()
    }

    // Routing can be derived either from the state as a single source of truth (similar to SwiftUI),
    // or from event, when we need to perform fire-and-forget routing (i.e. push next scene, or show alert).
    // By default routes are derived from events (state is attached when event happens) to not sync navigation logic with state.
    var routes: Observable<Route> {
        return system.eventsWithState.compactMap { [weak self] event, state in
            switch event {
            case .action(.didTapCloseButton):
                return .dismiss

            default:
                return nil
            }
        }
    }

    init(
        scheduler: SchedulerType = MainScheduler.instance
    ) {
        system = FeedbackSystem(
            initial: .initial,
            scheduler: scheduler,
            reduce: State.reduce,
            feedbacks: [
                Feedback.just(effects: actions.map(Event.action))
            ]
        )
    }

    func dispatch(_ action: Action) {
        actions.accept(action)
    }
}

fileprivate extension ___VARIABLE_store:identifier___ {
    // Decalre feedbacks here using static functions to describe side effects 
    // that should be performed when state changes, or event is fired.
    // and inject any dependencies needed for each feedback so that they aren't stored explicitly inside the store.
    //
    // static func someEffect(dependency: Dependency) -> Feedback<State, Event> { /* ... */ }
}

// MARK: - Routes

extension ___VARIABLE_store:identifier___ {
    // List routing actions here. Cases might have callbacks as associated values when needed to return back some data.
    enum Route {
        case dismiss
    }
}
