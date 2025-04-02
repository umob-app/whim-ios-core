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
    var bottomPanelInitialStickyPoint: BottomPanelStickyPoint { .fromBottom(.points(200)) }
    var bottomPanelStickyPoints: Set<BottomPanelStickyPoint> {
        let safeAreaInsets = view.superview?.safeAreaInsets ?? view.safeAreaInsets
        return [
            // 1 is for button shadow offset
            .fromTop(.points(WhimTopBarWithButton.UI.buttonPadding - 1 + safeAreaInsets.top)),
            .fromBottom(.points(50))
        ]
    }

    private let topView = TopView()
    private let detailsLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupTopView()
        setupDetailLabel()
    }

    private func setupView() {
        view.backgroundColor = .white
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.25
        view.layer.shadowRadius = 2
        view.layer.shadowOffset = CGSize(width: 0, height: -1)
        view.layer.cornerRadius = 4
    }

    private func setupTopView() {
        view.addSubview(topView)
        NSLayoutConstraint.activate([
            topView.topAnchor.constraint(equalTo: view.topAnchor),
            topView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupDetailLabel() {
        detailsLabel.translatesAutoresizingMaskIntoConstraints = false
        detailsLabel.textAlignment = .center
        detailsLabel.numberOfLines = 4
        detailsLabel.font = UIFont.preferredFont(forTextStyle: .title1).withWeight(.bold)
        detailsLabel.isUserInteractionEnabled = true
        detailsLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.didTapOnCountryInfo(_:))))

        view.addSubview(detailsLabel)
        NSLayoutConstraint.activate([
            detailsLabel.topAnchor.constraint(equalTo: topView.bottomAnchor),
            detailsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            detailsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            detailsLabel.heightAnchor.constraint(equalToConstant: 150)
        ])
    }

    func render(state newState: State) {
        guard state != newState else {
            return
        }
        state = newState
        detailsLabel.text = state.map.country.value.map {
            "\($0.flag)\n\($0.name)\n\($0.region)"
        }
    }

    @objc
    private func didTapOnCountryInfo(_ sender: UITapGestureRecognizer) {
        dispatch(.didTapOnCountryInfo)
    }
}
