//___FILEHEADER___

import Foundation
import WhimCore
import RxSwift
import RxRelay

// MARK: - State

extension ___VARIABLE_service:identifier___ {
    struct State {
        static let initial: State = .init()
    }
}

// MARK: - Actions & Events

extension ___VARIABLE_service:identifier___ {
    enum Action {
    }

    enum Event {
        case action(Action)
    }
}

// MARK: - Reducer

extension ___VARIABLE_service:identifier___.State {
    // swiftlint:disable:next superfluous_disable_command cyclomatic_complexity
    static func reduce(state: inout ___VARIABLE_service:identifier___.State, event: ___VARIABLE_service:identifier___.Event) {
        switch event {
        }
    }
}

// MARK: - Service

typealias ___VARIABLE_serving:identifier___ = AbstractService<___VARIABLE_service:identifier___.State, ___VARIABLE_service:identifier___.Action>

final class ___VARIABLE_service:identifier___: ___VARIABLE_serving:identifier___ {
    private let system: FeedbackSystem<State, Event>
    private let actions = PublishRelay<Action>()

    override var state: ObservableProperty<State> { system.state }

    init(
        scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .userInitiated, internalSerialQueueName: "com.whim.___VARIABLE_service:identifier___")
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

    override func dispatch(_ action: Action) {
        actions.accept(action)
    }
}

fileprivate extension ___VARIABLE_service:identifier___ {
    // static func someEffect(dependency: Dependency) -> Feedback<State, Event> { /* ... */ }
}
