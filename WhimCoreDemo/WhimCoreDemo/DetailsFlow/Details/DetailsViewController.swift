import UIKit
import WhimCore

final class DetailsViewController: UIViewController, WhimScenePresentation, BottomPanel {
    typealias State = DetailsStore.State
    typealias Action = DetailsStore.Action

    var output: DetailsViewController.Dispatch?

    private(set) var state: State = .initial(countryCode: "")

    private(set) lazy var bottomPanelHandler = {
        BottomPanelHandler(bottomPanel: self)
    }()

    // var bottomPanelScrollView: UIScrollView? { tableView }
    var bottomPanelIgnoreExistingTopConstraint: Bool { true }
    var bottomPanelBounceOffset: BottomPanelBounceOffset { .top(35) }
    var bottomPanelInitialStickyPoint: BottomPanelStickyPoint { .fromBottom(.points(50)) }
    var bottomPanelStickyPoints: Set<BottomPanelStickyPoint> {
        let safeAreaInsets = view.superview?.safeAreaInsets ?? view.safeAreaInsets
        return [
            // 1 is for button shadow offset
            .fromTop(.points(WhimTopBarWithCloseButton.UI.buttonPadding - 1 + safeAreaInsets.top)),
            .fromBottom(.percent(0.4))
        ]
    }

    func render(state: State) {
        self.state = state
    }
}
