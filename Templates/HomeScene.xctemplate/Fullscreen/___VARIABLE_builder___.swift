//___FILEHEADER___

import UIKit
import WhimCore

enum ___VARIABLE_builder:identifier___ {
    static func make(
        router: @escaping (___VARIABLE_store:identifier___.Route) -> Void
    ) -> HomeSingleScene {
        let scene = ___VARIABLE_viewController:identifier___(nibName: "___VARIABLE_viewController:identifier___", bundle: nil)
        let store = ___VARIABLE_store:identifier___()

        store.bind(fullscreen: .init(presentation: scene), router: router)

        return HomeSingleScene(fullscreen: scene)
    }
}
