import WhimCore

// MARK: - Builder

enum LandingFlowBuilder {
    static func make(intent: LandingFlowIntent, router: @escaping HomeFlowRouter) -> WhimScene {
        LandingFlow(intent: intent, router: router)
    }
}

// MARK: - Flow

final class LandingFlow: WhimSceneNavigationStack {
    private let router: HomeFlowRouter

    init(intent: LandingFlowIntent, router: @escaping HomeFlowRouter) {
        self.router = router
        super.init([])

        switch intent {
        case .landing: showLanding()
        case .onboarding: showOnboarding()
        }
    }
}

private extension LandingFlow {
    func showLanding() {
        let scene = LandingBuilder.make(router: { [weak self] route in
            switch route {
            case .dismiss: self?.router(.dismiss)
            case let .showDetails(code): self?.router(.navigate(.showDetails(code)))
            }
        })
        push(scene: scene)
    }
}

private extension LandingFlow {
    func showOnboarding() {
//        let scene = OnboardingBuilder.make(router: { [weak self] route in
//            guard let self = self else { return }
//
//            switch route {
//            case .dismiss: self.router(.dismiss)
//            }
//        })
//        push(scene: scene)
    }
}

// MARK: - Intent

enum LandingFlowIntent: Equatable {
    case onboarding
    case landing
}
