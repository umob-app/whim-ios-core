//___FILEHEADER___

import Foundation
import WhimCore
import RxSwift
import RxRelay

// MARK: - State

extension ___VARIABLE_store:identifier___ {
    struct State {
        static let initial: State = .init()
    }
}

// MARK: - Actions & Events

extension ___VARIABLE_store:identifier___ {
    enum Action {
        case didTapCloseButton
    }

    enum Event {
        case action(Action)
    }
}

// MARK: - Reducer

extension ___VARIABLE_store:identifier___.State {
    // swiftlint:disable:next superfluous_disable_command cyclomatic_complexity
    static func reduce(state: inout ___VARIABLE_store:identifier___.State, event: ___VARIABLE_store:identifier___.Event) {
        switch event {
        case .action(.didTapCloseButton):
            break
        }
    }
}

// MARK: - Store

final class ___VARIABLE_store:identifier___: WhimSceneStore {
    private let system: FeedbackSystem<State, Event>
    private let actions = PublishRelay<Action>()

    var state: Observable<State> { system.asObservable() }

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
    // static func someEffect(dependency: Dependency) -> Feedback<State, Event> { /* ... */ }
}

// MARK: - Routes

extension ___VARIABLE_store:identifier___ {
    enum Route {
        case dismiss
    }
}
