import Foundation
import RxSwift
import RxRelay
import WhimCore

// MARK: - Builder

enum HomeFlowBuilder {
    static func make() -> HomeFlow {
        HomeFlow(
            worldGeometryService: ServiceLocator.current.worldGeometryService
        )
    }
}

// MARK: - State

extension HomeFlow {
    struct State: Equatable {
        var isLoaded: Bool
        var flows: [ObjectIdentifier: HomeFlowRoute.NavigationLink]

        static let initial: State = .init(
            isLoaded: false,
            flows: [:]
        )
    }
}

private extension HomeFlow.State {
    func link(for scene: WhimScene) -> HomeFlowRoute.NavigationLink? {
        flows[ObjectIdentifier(scene)]
    }
}

// MARK: - Actions & Events

extension HomeFlow {
    enum Action {
        case didLoad
        case route(HomeFlowRoute)
    }

    enum Event {
        case action(Action)
        case didUpdateFlows(ins: [ObjectIdentifier: HomeFlowRoute.NavigationLink], del: [ObjectIdentifier])
    }
}

// MARK: - Reducer

extension HomeFlow.State {
    static func reduce(state: inout HomeFlow.State, event: HomeFlow.Event) {
        switch event {
        case let .didUpdateFlows(insert, delete):
            delete.forEach { state.flows.removeValue(forKey: $0) }
            state.flows.merge(insert, uniquingKeysWith: { _, new in new })
        case .action(.didLoad):
            state.isLoaded = true
        case .action(.route):
            return
        }
    }
}

final class HomeFlow {
    private let system: FeedbackSystem<State, Event>
    private let actions = PublishRelay<Action>()

    var state: Observable<State> {
        system.asObservable()
    }

    let stack: WhimSceneNavigationStack

    init(
        scheduler: SchedulerType = MainScheduler.instance,
        worldGeometryService: WorldGeometryServing
    ) {
        stack = WhimSceneNavigationStack([])
        system = FeedbackSystem(
            initial: .initial,
            scheduler: scheduler,
            reduce: State.reduce,
            feedbacks: [
                .just(effects: actions.map(Event.action)),
                Self.startServices(worldGeometryService: worldGeometryService),
                Self.handleNavigation(stack: stack),
            ]
        )
    }

    func dispatch(_ action: Action) {
        actions.accept(action)
    }
}

// MARK: - Navigation

fileprivate extension HomeFlow {
    static func startServices(
        worldGeometryService: WorldGeometryServing
    ) -> Feedback<State, Event> {
        .whenBecomesTrue(state: \.isLoaded) { [weak worldGeometryService] _ in
            worldGeometryService?.dispatch(.start)
            return .empty()
        }
    }

    static func handleNavigation(
        stack: WhimSceneNavigationStack
    ) -> Feedback<State, Event> {
        .imperative { [weak stack] dispatch in
            return { state, event in
                guard let stack = stack else {
                    return
                }
                if case .action(.didLoad) = event {
                    return navigate(link: .initial, stack: stack, state: state, dispatch: dispatch)
                }
                guard case let .action(.route(route)) = event else {
                    return
                }
                switch route {
                case .popToRoot:
                    popToRoot(stack: stack, dispatch: dispatch)

                case .dismiss:
                    dismiss(stack: stack, state: state, dispatch: dispatch)

                case let .navigate(link):
                    navigate(link: link, stack: stack, state: state, dispatch: dispatch)

                case let .handleDeeplink(deeplink):
                    return
                    // TODO: implement deeplink handler
//                    handleDeepLink(deeplink)
                }
            }
        }
    }

    private static func popToRoot(stack: WhimSceneNavigationStack, dispatch: @escaping (HomeFlow.Event) -> Void) {
        if let poppedFlows = stack.popToRoot() {
            return dispatch(.didUpdateFlows(ins: [:], del: poppedFlows.map(ObjectIdentifier.init)))
        }
    }

    private static func dismiss(stack: WhimSceneNavigationStack, state: HomeFlow.State, dispatch: @escaping (HomeFlow.Event) -> Void) {
        let toFrom = stack.scenes.suffix(2)
        guard toFrom.count == 2, let to = toFrom.first, let from = toFrom.last else {
            return
        }
        let animation = animatedTransition(from: state.link(for: from), to: state.link(for: to), isPresenting: false)
        if let poppedFlows = stack.pop(animating: animation).map({ [$0] }) {
            return dispatch(.didUpdateFlows(ins: [:], del: poppedFlows.map(ObjectIdentifier.init)))
        }
    }

    private static func navigate(link: HomeFlowRoute.NavigationLink, stack: WhimSceneNavigationStack, state: HomeFlow.State, dispatch: @escaping (HomeFlow.Event) -> Void) {
        let animation = animatedTransition(from: stack.scenes.last.flatMap(state.link), to: link, isPresenting: true)

        if link == .initial, let poppedFlows = stack.popToRoot() {
            return dispatch(.didUpdateFlows(ins: [:], del: poppedFlows.map(ObjectIdentifier.init)))
        }
        if let scene = scene(for: link, dispatch: dispatch) {
            stack.push(scene: scene, animating: animation)
            return dispatch(.didUpdateFlows(ins: [ObjectIdentifier(scene): link], del: []))
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func scene(for link: HomeFlowRoute.NavigationLink, dispatch: @escaping (HomeFlow.Event) -> Void) -> WhimScene? {
        let router: HomeFlowRouter = { dispatch(.action(.route($0))) }
        return switch link {
        case .showOnboarding:
            LandingFlowBuilder.make(intent: .onboarding, router: router)
        case .showLanding:
            LandingFlowBuilder.make(intent: .landing, router: router)
        case let .showDetails(code):
            DetailsFlowBuilder.make(intent: DetailsFlowIntent(countryCode: code), router: router)
        }
    }

    private static func animatedTransition(from: HomeFlowRoute.NavigationLink?, to: HomeFlowRoute.NavigationLink?, isPresenting: Bool) -> WhimSceneAnimatedTransitioning {
        switch (from, to) {
        case (.none, .some):
            return WhimSceneAnimatedTransitions.None()
        case (_, _):
            return isPresenting
                ? WhimSceneAnimatedTransitions.Modal(.present)
                : WhimSceneAnimatedTransitions.Modal(.dismiss)
        }
    }
}

// MARK: - Route

typealias HomeFlowRouter = (HomeFlowRoute) -> Void

enum HomeFlowRoute: Equatable {
    enum NavigationLink: Equatable {
        static var initial: NavigationLink {
            .showLanding
        }

        case showOnboarding
        case showLanding
        case showDetails(CountryCode)
    }

    case popToRoot
    case dismiss
    case handleDeeplink(URL)
    case navigate(NavigationLink)
}
