import WhimCore

// MARK: - Builder

enum DetailsFlowBuilder {
    static func make(intent: DetailsFlowIntent, router: @escaping HomeFlowRouter) -> WhimScene {
        DetailsFlow(intent: intent, router: router)
    }
}

// MARK: - Flow

final class DetailsFlow: WhimSceneNavigationStack {
    private let router: HomeFlowRouter

    init(intent: DetailsFlowIntent, router: @escaping HomeFlowRouter) {
        self.router = router
        super.init([])

        showDetails(for: intent.countryCode)
    }
}

private extension DetailsFlow {
    func showDetails(for countryCode: CountryCode) {
        let scene = DetailsBuilder.make(countryCode: countryCode) { [weak self] route in
            switch route {
            case .dismiss: self?.router(.dismiss)
            }
        }
        push(scene: scene)
    }
}

// MARK: - Intent

struct DetailsFlowIntent: Equatable {
    let countryCode: CountryCode
}
