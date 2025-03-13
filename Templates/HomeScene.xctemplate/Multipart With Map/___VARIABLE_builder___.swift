//___FILEHEADER___

import UIKit
import WhimCore
import RxSwift
import RxCocoa

// MARK: - Builder

enum ___VARIABLE_builder:identifier___ {
    static func make(
        router: @escaping (___VARIABLE_store:identifier___.Route) -> Void
    ) -> HomeSingleScene {
        let topBar = CloseButtonTopBarViewController()
        let bottomSheet = ___VARIABLE_bottom:identifier___(nibName: "___VARIABLE_bottom:identifier___", bundle: nil)
        let map = ___VARIABLE_map:identifier___(mapLayerManager: World.current.managers.mapLayer)
        let store = ___VARIABLE_store:identifier___()

        store.bind(
            top: .init(presentation: topBar, state: { _ in () }, action: ___VARIABLE_store:identifier___.Action.init),
            bottom: .init(presentation: bottomSheet),
            map: .init(presentation: map, state: ___VARIABLE_map:identifier___.State.init, action: ___VARIABLE_store:identifier___.Action.init),
            router: router
        )
        _ = bottomSheet.rx.isActive.takeUntil(bottomSheet.rx.deallocated).bind { [weak store] isActive in
            store?.dispatch(.didBecomeActive(isActive))
        }
        return HomeSingleScene(top: topBar, bottom: bottomSheet)
    }
}

// MARK: - States & Actions Map

fileprivate extension ___VARIABLE_map:identifier___.State {
    init(state: ___VARIABLE_store:identifier___.State) {
        self = state.map
    }
}

fileprivate extension ___VARIABLE_store:identifier___.Action {
    init(action: ___VARIABLE_map:identifier___.Action) {
        self = .map(action)
    }
}

fileprivate extension ___VARIABLE_store:identifier___.Action {
    init(action: CloseButtonTopBarViewController.Action) {
        switch action {
        case .didTapCloseButton: self = .didTapCloseButton
        }
    }
}
