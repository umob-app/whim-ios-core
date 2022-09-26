//___FILEHEADER___

import UIKit
import WhimCore

final class ___VARIABLE_viewController:identifier___: UIViewController, ScenePresentation {
    // View controller's state and action are referencing store types by default.
    // Sometimes it might be a better practice to keep own view state here for better abstraction from business logic layer.
    // However it might cause more duplication, so it all depends on how we decide to do it in our team.
    typealias State = ___VARIABLE_store:identifier___.State
    typealias Action = ___VARIABLE_store:identifier___.Action

    // Set this property if you want to receive actions from ViewController.
    // Usually it will be binded to the Store inside Builder.
    // However you can set your custom delegate here when prototyping or developing UI in Playground without Store.
    var output: ___VARIABLE_viewController:identifier___.Dispatch?

    private(set) var state: State = .initial

    func render(state: State) {
        // Perform any diffing before setting new state.
        // Perfect place to reload table with changes from diff applied to it.
        //
        // There are times, when state changes more often than once in a layout cycle iteration (calls this `render` method),
        // and UI is noticeably lagging, and not being able to render 60fps,
        // it might be more efficient to not do anything here yet,
        // but just tell layout engine to redraw, when it's ready (`view.setNeedsLayout()`) 
        // and perform actual work inside `viewWillLayoutSubviews`.
        // This way rendering will be performed only once per layout cycle iteration, however this trick is not usually needed.
        self.state = state
    }
}
