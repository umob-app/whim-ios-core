//___FILEHEADER___

import UIKit
import WhimCore

// MARK: - Builder

enum ___VARIABLE_builder:identifier___ {
    static func make(
        router: @escaping (___VARIABLE_store:identifier___.Route) -> Void
    ) -> HomeSingleScene {
        let topBar = CloseButtonTopBarViewController()
        let bottomSheet = ___VARIABLE_bottom:identifier___(nibName: "___VARIABLE_bottom:identifier___", bundle: nil)
        let store = ___VARIABLE_store:identifier___()

        store.bind(
            top: .init(presentation: topBar, state: { _ in () }, action: ___VARIABLE_store:identifier___.Action.init),
            bottom: .init(presentation: bottomSheet),
            map: .none,
            router: router
        )
        return HomeSingleScene(top: topBar, bottom: bottomSheet)
    }
}

// MARK: - States & Actions Map

fileprivate extension ___VARIABLE_store:identifier___.Action {
    init(action: CloseButtonTopBarViewController.Action) {
        switch action {
        case .didTapCloseButton: self = .didTapCloseButton
        }
    }
}
