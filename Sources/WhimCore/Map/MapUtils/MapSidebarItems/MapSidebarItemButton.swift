import UIKit

/// A button that is used to render map sidebar menu item with any given content.
public final class MapSidebarItemButton: UIButton {
    public let item: MapSidebarItem

    required public init(item: MapSidebarItem) {
        self.item = item
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalTo: widthAnchor, multiplier: 1).isActive = true

        layer.cornerRadius = 20
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 2
        layer.shadowOpacity = 0.22
        layer.shadowOffset = .zero
        backgroundColor = .white

        updateContent()
        // using passthrough view to show highlight on top of any content when user taps on it
        addCustomView(PassthroughView())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateContent(isHighlighted: Bool = false) {
        switch item.content(isHighlighted: isHighlighted) {
        case let .image(image, tintColor):
            if let tintColor = tintColor {
                self.tintColor = tintColor
            }
            setImage(image, for: .normal)
        case let .view(view):
            addCustomView(view)
        }
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

    public override var isHighlighted: Bool {
        didSet {
            subviews.first(where: { $0 is PassthroughView })?.backgroundColor = isHighlighted
                ? UIColor.black.withAlphaComponent(0.06)
                : UIColor.clear
        }
    }
}

public extension MapSidebarItem {
    var buttonKeyPath: KeyPath<MapSidebarItemButton, Bool> {
        switch self {
        case .trackUser: return \.item.isTrackUser
        case .reload: return \.item.isReload
        case .custom: return \.item.isCustom
        case .filter: return \.item.isFilter
        }
    }
}
