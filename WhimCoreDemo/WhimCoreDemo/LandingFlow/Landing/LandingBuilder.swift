import UIKit
import WhimCore
import RxSwift
import RxCocoa

// MARK: - Builder

enum LandingBuilder {
    static func make(
        router: @escaping (LandingStore.Route) -> Void
    ) -> WhimSingleScene {
        let topBar = WhimTopBarWithCloseButton()
        let bottomSheet = LandingViewController()
        let map = LandingMap(mapLayerManager: ServiceLocator.current.mapLayerManager)
        let store = LandingStore(worldGeometryService: ServiceLocator.current.worldGeometryService)

        store.bind(
            top: .init(presentation: topBar, state: { _ in () }, action: LandingStore.Action.init),
            bottom: .init(presentation: bottomSheet),
            map: .init(presentation: map, state: LandingMap.State.init, action: LandingStore.Action.init),
            router: router
        )
        _ = bottomSheet.rx.isActive.take(until: bottomSheet.rx.deallocated).bind { [weak store] isActive in
            store?.dispatch(.didBecomeActive(isActive))
        }
        return WhimSingleScene(top: topBar, bottom: bottomSheet)
    }
}

// MARK: - States & Actions Map

fileprivate extension LandingMap.State {
    init(state: LandingStore.State) {
        self = state.map
    }
}

fileprivate extension LandingStore.Action {
    init(action: LandingMap.Action) {
        self = .map(action)
    }
}

fileprivate extension LandingStore.Action {
    init(action: WhimTopBarWithCloseButton.Action) {
        switch action {
        case .didTapCloseButton: self = .didTapCloseButton
        }
    }
}
