import UIKit

/// Default implementation of Top Bar Controller with a button.
public final class WhimTopBarWithButton: WhimScenePresentationViewController {
    public typealias State = Void

    public enum Action {
        case didTapTopBarButton
    }

    public enum UI {
        public static let buttonPadding: CGFloat = 16
        public static let buttonSize: CGFloat = 48
    }

    public var output: WhimTopBarWithButton.Dispatch?

    private let topBarButton = TopBarButton()

    public init(icon: UIImage = UIImage(systemName: "xmark")!) {
        super.init(nibName: nil, bundle: nil)
        topBarButton.setImage(icon, for: .normal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    public override func loadView() {
        view = PassthroughView()
    }

    public func render(state: State) {}

    private func setupUI() {
        view.backgroundColor = .clear

        view.addSubview(topBarButton)
        topBarButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topBarButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: UI.buttonPadding),
            topBarButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: UI.buttonPadding),
            topBarButton.widthAnchor.constraint(equalToConstant: UI.buttonSize),
            topBarButton.heightAnchor.constraint(equalToConstant: UI.buttonSize),
            view.bottomAnchor.constraint(equalTo: topBarButton.bottomAnchor)
        ])

        topBarButton.addTarget(self, action: #selector(topButtonDidTap), for: .touchUpInside)
    }

    @objc private func topButtonDidTap() {
        dispatch(.didTapTopBarButton)
    }
}

/// A button for the default top bar controller, with a user-experience similar to `MapSidebarItemButton`.
final class TopBarButton: UIButton {
    override var isHighlighted: Bool {
        didSet {
            subviews.first(where: { $0 is PassthroughView })?.backgroundColor = isHighlighted
                ? UIColor.black.withAlphaComponent(0.06)
                : UIColor.clear
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        config()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        config(size: frame.width)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        config(size: frame.width)
    }

    private func config(size: CGFloat = WhimTopBarWithButton.UI.buttonSize) {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalTo: widthAnchor, multiplier: 1).isActive = true

        setTitle(nil, for: .normal)
        setImage(UIImage(systemName: "xmark"), for: .normal)
        contentMode = .scaleAspectFit
        contentHorizontalAlignment = .center
        contentVerticalAlignment = .center
        tintColor = .darkGray
        backgroundColor = .white
        layer.cornerRadius = size / 2
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 2
        layer.shadowOpacity = 0.22
        layer.shadowOffset = .zero

        addCustomView(PassthroughView())
    }

    private func addCustomView(_ view: UIView) {
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = layer.cornerRadius
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}
