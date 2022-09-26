//___FILEHEADER___

import UIKit
import WhimCore

// Builder is a very simple piece of logic.
// It connects ViewController to the Store and passes dependencies it needs.
// Builder can access Current World container and is usually not unit-tested.
enum ___VARIABLE_builder:identifier___ {
    static func make(
        // Add another dependencies needed for the Store, here. However don't put anything here if it can be accessed from the World container.
        router: @escaping (___VARIABLE_viewController:identifier___, ___VARIABLE_store:identifier___.Route) -> Void
    ) -> ___VARIABLE_viewController:identifier___ {
        let scene = ___VARIABLE_viewController:identifier___(nibName: "___VARIABLE_viewController:identifier___", bundle: nil)
        let store = ___VARIABLE_store:identifier___()
        // Binding store to the view controller and retaining store by it until it dies.
        //
        // It will start updating view controller with state changes once `viewDidLoad` is called, 
        // so that view controller doesn't try to render anything before view is loaded.
        //
        // Those who present, are also responsible for dismissing, as they keep knowledge about presentation logic and surrounding context.
        // Thus scene shouldn't try to dismiss itself. Router callback will be executed on main queue.
        store.bind(fullscreen: .init(presentation: scene), router: { [weak scene] route in scene.map { router($0, route) } })

        return scene
    }
}
