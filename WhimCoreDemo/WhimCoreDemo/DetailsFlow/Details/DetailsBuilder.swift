import UIKit
import WhimCore
import RxSwift
import RxCocoa

// MARK: - Builder

enum DetailsBuilder {
    static func make(
        countryCode: CountryCode,
        router: @escaping (DetailsStore.Route) -> Void
    ) -> WhimSingleScene {
        let topBar = WhimTopBarWithButton()
        let bottomSheet = DetailsViewController()
        let map = DetailsMap(mapLayerManager: ServiceLocator.current.mapLayerManager)
        let store = DetailsStore(
            countryCode: countryCode,
            worldGeometryService: ServiceLocator.current.worldGeometryService
        )

        store.bind(
            top: .init(presentation: topBar, state: { _ in () }, action: DetailsStore.Action.init),
            bottom: .init(presentation: bottomSheet),
            map: .init(presentation: map, state: DetailsMap.State.init, action: DetailsStore.Action.init),
            router: router
        )
        _ = bottomSheet.rx.isActive.take(until: bottomSheet.rx.deallocated).bind { [weak store] isActive in
            store?.dispatch(.didBecomeActive(isActive))
        }
        return WhimSingleScene(top: topBar, bottom: bottomSheet)
    }
}

// MARK: - States & Actions Map

fileprivate extension DetailsMap.State {
    init(state: DetailsStore.State) {
        self = state.map
    }
}

fileprivate extension DetailsStore.Action {
    init(action: DetailsMap.Action) {
        self = .map(action)
    }
}

fileprivate extension DetailsStore.Action {
    init(action: WhimTopBarWithButton.Action) {
        switch action {
        case .didTapTopBarButton: self = .didTapCloseButton
        }
    }
}
