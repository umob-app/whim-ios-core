//___FILEHEADER___

import UIKit
import WhimCore

final class ___VARIABLE_viewController:identifier___: UIViewController, WhimScenePresentation {
    typealias State = ___VARIABLE_store:identifier___.State
    typealias Action = ___VARIABLE_store:identifier___.Action

    var output: ___VARIABLE_viewController:identifier___.Dispatch?

    private(set) var state: State = .initial

    func render(state: State) {
        self.state = state
    }
}
