import UIKit
import WhimCore

/// Default implementation of Top Bar Controller with a close button.
public final class WhimTopBarWithCloseButton: WhimScenePresentationViewController {
    public typealias State = Void

    public enum Action {
        case didTapCloseButton
    }

    public enum UI {
        public static let buttonPadding: CGFloat = 16
        public static let buttonSize: CGFloat = 48
    }

    public var output: WhimTopBarWithCloseButton.Dispatch?

    private let closeButton = CloseButton()

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

        view.addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: UI.buttonPadding),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: UI.buttonPadding),
            closeButton.widthAnchor.constraint(equalToConstant: UI.buttonSize),
            closeButton.heightAnchor.constraint(equalToConstant: UI.buttonSize),
            view.bottomAnchor.constraint(equalTo: closeButton.bottomAnchor)
        ])

        closeButton.addTarget(self, action: #selector(closeButtonDidTap), for: .touchUpInside)
    }

    @objc private func closeButtonDidTap() {
        dispatch(.didTapCloseButton)
    }
}

/// A button for the default top bar controller, with a user-experience similar to `MapSidebarItemButton`.
final class CloseButton: UIButton {
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

    private func config(size: CGFloat = WhimTopBarWithCloseButton.UI.buttonSize) {
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
