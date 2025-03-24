import UIKit
import WhimCore

final class LandingViewController: UIViewController, WhimScenePresentation, BottomPanel, UITableViewDelegate, UITableViewDataSource {
    typealias State = LandingStore.State
    typealias Action = LandingStore.Action

    enum UI {
        static let topViewHeight: CGFloat = 40
        static let sectionHeight: CGFloat = 50
        static let rowHeight: CGFloat = 35

        static let errorMessage: [NSAttributedString.Block] = [
            .text("Something went wrong.\nPress "),
            .symbol("arrow.clockwise"),
            .text(" to reload."),
        ]
        static let loadingMessage = "Fetching countries.\n⏳"
        static let emptyMessage = "No countries found.\n🎏"
    }

    var output: LandingViewController.Dispatch?

    private(set) var state: State = .initial

    private(set) lazy var bottomPanelHandler = {
        BottomPanelHandler(bottomPanel: self)
    }()

    var bottomPanelIgnoreExistingTopConstraint: Bool { true }
    var bottomPanelScrollView: UIScrollView? { tableView }
    var bottomPanelBounceOffset: BottomPanelBounceOffset { .top(35) }
    var bottomPanelInitialStickyPoint: BottomPanelStickyPoint { .fromBottom(.percent(0.4)) }
    var bottomPanelStickyPoints: Set<BottomPanelStickyPoint> {
        let safeAreaInsets = view.superview?.safeAreaInsets ?? view.safeAreaInsets
        return [
            // 1 is for button shadow offset
            .fromTop(.points(WhimTopBarWithCloseButton.UI.buttonPadding - 1 + safeAreaInsets.top)),
        ]
    }

    private let topView = UIImageView()
    private let tableView = UITableView()
    private let reuseId = "LandingViewControllerCell"

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupTopView()
        setupTableView()

        tableView.reloadData()
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
        topView.translatesAutoresizingMaskIntoConstraints = false
        topView.image = UIImage(systemName: "line.3.horizontal")!
        topView.contentMode = .center
        topView.tintColor = .lightGray

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = .separator

        topView.addSubview(separator)
        view.addSubview(topView)
        NSLayoutConstraint.activate([
            topView.topAnchor.constraint(equalTo: view.topAnchor),
            topView.heightAnchor.constraint(equalToConstant: UI.topViewHeight),
            topView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            separator.leadingAnchor.constraint(equalTo: topView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: topView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: topView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.estimatedRowHeight = 35
        tableView.estimatedSectionHeaderHeight = 50
        tableView.bounces = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseId)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        state.countries.value?.keys.count ?? 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        state.countries.value?.elements[section].value.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseId, for: indexPath)
        cell.textLabel?.text = state.countries.value?.elements[indexPath.section].value[indexPath.row].description
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        state.countries.value?.elements[section].key
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }

        header.textLabel?.font = UIFont.boldSystemFont(ofSize: 20)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let country = state.countries.value?.elements[indexPath.section].value[indexPath.row] {
            dispatch(.didSelectCountry(country))
        }
    }

    func render(state newState: State) {
        renderMessage(newState)
        state = newState
        tableView.reloadData()
    }

    private func renderMessage(_ newState: State) {
        guard state.countries != newState.countries else {
            return
        }
        switch newState.countries {
        case .idle:
            tableView.tableHeaderView = nil
        case .loading(.none):
            tableView.tableHeaderView = makeStatusView(message: .init(string: UI.loadingMessage))
        case let .loading(countries?):
            tableView.tableHeaderView = countries.isEmpty
                ? makeStatusView(message: .init(string: UI.loadingMessage))
                : nil
        case let .loaded(countries):
            tableView.tableHeaderView = countries.isEmpty
                ? makeStatusView(message: .init(string: UI.emptyMessage))
                : nil
        case .failed(.none, _):
            tableView.tableHeaderView = makeStatusView(message: .make(
                blocks: UI.errorMessage,
                font: .preferredFont(forTextStyle: .title1).withWeight(.bold),
                textColor: .darkText
            ))
        case let .failed(countries?, _):
            showToast(message: .make(blocks: UI.errorMessage, textColor: .white), background: .systemRed)
            tableView.tableHeaderView = countries.isEmpty
                ? makeStatusView(message: .init(string: UI.emptyMessage))
                : nil
        }
    }

    private func makeStatusView(message: NSAttributedString) -> UIView {
        let statusView = UILabel(frame: tableView.bounds)
        statusView.textAlignment = .center
        statusView.numberOfLines = 2
        statusView.font = UIFont.preferredFont(forTextStyle: .title1).withWeight(.bold)
        statusView.attributedText = message
        return statusView
    }
}
