//___FILEHEADER___

import UIKit
import WhimCore

final class ___VARIABLE_bottom:identifier___: UIViewController, WhimScenePresentation, BottomPanel {
    typealias State = ___VARIABLE_store:identifier___.State
    typealias Action = ___VARIABLE_store:identifier___.Action

    var output: ___VARIABLE_bottom:identifier___.Dispatch?

    private(set) var state: State = .initial

    private(set) lazy var bottomPanelHandler = {
        BottomPanelHandler(bottomPanel: self)
    }()

    var bottomPanelScrollView: UIScrollView? { nil }
    var bottomPanelIgnoreExistingTopConstraint: Bool { true }
    var bottomPanelBounceOffset: BottomPanelBounceOffset { .top(35) }
    var bottomPanelInitialStickyPoint: BottomPanelStickyPoint { .fromBottom(.percent(0.4)) }
    var bottomPanelStickyPoints: Set<BottomPanelStickyPoint> {
        let safeAreaInsets = view.superview?.safeAreaInsets ?? view.safeAreaInsets
        return [
            // 1 is for button shadow offset
            .fromTop(.points(WhimTopBarWithButton.UI.buttonPadding - 1 + safeAreaInsets.top)),
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func render(state: State) {
        self.state = state
    }
}
