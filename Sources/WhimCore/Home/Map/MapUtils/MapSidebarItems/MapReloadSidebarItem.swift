import UIKit

/// Represents a reloading icon image-view.
/// Has `style` variable, changing which will render correct state.
public final class MapReloadSidebarItemView: UIImageView {
    private static let highlightColor = UIColor(red: 3 / 255, green: 153 / 255, blue: 253 / 255, alpha: 1)

    private static var icon: UIImage? {
        return WhimCore.image(named: "map-reload-icon")
    }

    // sourcery: Random
    public enum Style: CaseIterable, Equatable {
        case normal
        case highlighted
        case spinning
    }

    public var style: Style {
        willSet {
            apply(newValue)
        }
    }

    public init(style: Style = .normal) {
        self.style = style
        super.init(frame: .zero)
        contentMode = .center

        apply(style, force: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func apply(_ style: Style, force: Bool = false) {
        guard self.style != style || force else {
            return
        }
        layer.removeAllAnimations()

        switch style {
        case .normal:
            image = Self.icon?.withRenderingMode(.alwaysOriginal)
            tintColor = .clear
            backgroundColor = .white
        case .highlighted:
            image = Self.icon?.withRenderingMode(.alwaysTemplate)
            tintColor = .white
            backgroundColor = Self.highlightColor
        case .spinning:
            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.toValue = NSNumber(value: Double.pi * 2)
            rotation.duration = 2
            rotation.isCumulative = true
            rotation.repeatCount = Float.greatestFiniteMagnitude
            rotation.isRemovedOnCompletion = false
            layer.add(rotation, forKey: "rotationAnimation")

            image = Self.icon?.withRenderingMode(.alwaysTemplate)
            tintColor = .white
            backgroundColor = Self.highlightColor
        }
    }
}
