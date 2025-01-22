import UIKit
import WhimCore

// Just an initial demo scene consisting of top and bottom view-controllers.

public class InitialSceneTopBar: UIViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        let label = UILabel()
        label.numberOfLines = 1
        label.text = "Welcome to Whim!"
        label.font = UIFont.systemFont(ofSize: 20)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 15),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: label.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: 15)
        ])
    }
}

public class InitialSceneBottomSheet: UIViewController, BottomPanel, UITableViewDelegate, UITableViewDataSource {
    public private(set) lazy var bottomPanelHandler = {
        BottomPanelHandler(bottomPanel: self)
    }()
    public var bottomPanelScrollView: UIScrollView? { tableView }
    public var bottomPanelInitialStickyPoint: BottomPanelStickyPoint { .fromBottom(.points(100)) }

    private let topView = UIView()
    private let tableView = UITableView()
    private let countries = Locale.isoRegionCodes.map(Locale.current.localizedString(forRegionCode:))
    private let reuseId = "cell"

    public override func viewDidLoad() {
        super.viewDidLoad()

        topView.backgroundColor = .purple

        view.addSubview(topView)
        view.addSubview(tableView)

        topView.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topView.topAnchor.constraint(equalTo: view.topAnchor),
            topView.heightAnchor.constraint(equalToConstant: 40),
            topView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: topView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        tableView.bounces = true
        tableView.delegate = self
        tableView.dataSource = self

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseId)
        tableView.reloadData()
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        countries.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseId, for: indexPath)
        cell.textLabel?.text = countries[indexPath.row]
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// Another BottomPanel as UITableViewController to verify its behavior

//public class InitialSceneBottomSheet: UITableViewController, BottomPanel {
//    public let bottomPanelHandler = BottomPanelHandler()
//    public var bottomPanelScrollView: UIScrollView? { tableView }
//
//    private let countries = Locale.isoRegionCodes.map(Locale.current.localizedString(forRegionCode:))
//    private let reuseId = "cell"
//
//    public override func viewDidLoad() {
//        super.viewDidLoad()
//
//        bottomPanelHandler.bottomPanel = self
//
//        tableView.bounces = true
//
//        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseId)
//        tableView.reloadData()
//    }
//
//    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        countries.count
//    }
//
//    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let cell = tableView.dequeueReusableCell(withIdentifier: reuseId, for: indexPath)
//        cell.textLabel?.text = countries[indexPath.row]
//        return cell
//    }
//
//    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        tableView.deselectRow(at: indexPath, animated: true)
//    }
//}
