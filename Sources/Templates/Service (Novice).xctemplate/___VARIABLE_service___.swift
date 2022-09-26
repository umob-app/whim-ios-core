//___FILEHEADER___

import Foundation
import WhimCore
import RxSwift
import RxRelay

// MARK: - State

extension ___VARIABLE_service:identifier___ {
    struct State {
        // Describe state properties here or cases if it's enum.
        // It's better to declare properties as variables, as it will ease state mutations in reducer.

        static let initial: State = .init()
    }
}

// MARK: - Actions & Events

extension ___VARIABLE_service:identifier___ {
    enum Action {
        // Treat actions as service inputs.
    }

    enum Event {
        case action(Action)
        // Describe events that should trigger state changes.
    }
}

// MARK: - Reducer

extension ___VARIABLE_service:identifier___.State {
    // swiftlint:disable:next superfluous_disable_command cyclomatic_complexity
    static func reduce(state: inout ___VARIABLE_service:identifier___.State, event: ___VARIABLE_service:identifier___.Event) {
        switch event {
        // Change state here according to incoming events.
        }
    }
}

// MARK: - Service

typealias ___VARIABLE_serving:identifier___ = AbstractService<___VARIABLE_service:identifier___.State, ___VARIABLE_service:identifier___.Action>

final class ___VARIABLE_service:identifier___: ___VARIABLE_serving:identifier___ {
    private let system: FeedbackSystem<State, Event>
    private let actions = PublishRelay<Action>()

    override var state: ObservableProperty<State> {
        return system.state
    }

    init(
        scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .userInitiated, internalSerialQueueName: "com.whim2.___VARIABLE_service:identifier___")
        // Scheduler is injected to allow easier time-critical unit-testing with RxTest.
        // Inject other dependencies here as well.
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
    // Decalre feedbacks here using static functions to describe side effects that should be performed when state changes,
    // and inject any dependencies needed so that they should not be even explicitly stored inside the service.
    //
    // static func someEffect(dependency: Dependency) -> Feedback<State, Event> { /* ... */ }
}
