import UIKit

/// Represents a reloading icon image-view.
/// Has `style` variable, changing which will render respective state.
public final class MapReloadSidebarItemView: UIImageView {
    public static var defaultIcon: UIImage {
        return UIImage(systemName: "arrow.clockwise")!
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

    private var highlightColor: UIColor
    private var normalTintColor: UIColor
    private var icon: UIImage

    public init(icon: UIImage = MapReloadSidebarItemView.defaultIcon, style: Style = .normal, highlightColor: UIColor, normalTintColor: UIColor) {
        self.style = style
        self.highlightColor = highlightColor
        self.normalTintColor = normalTintColor
        self.icon = icon
        super.init(frame: .zero)
        contentMode = .center

        apply(style, force: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // this is needed to avoid this component to resize based on the symbol it's rendering,
    // but to size itself precisely according to autolayout requirements.
    // https://stackoverflow.com/a/78894452/1376429
    public override var alignmentRectInsets: UIEdgeInsets {
        .zero
    }

    private func apply(_ style: Style, force: Bool = false) {
        guard self.style != style || force else {
            return
        }
        if #available(iOS 18.0, *) {
            removeSymbolEffect(ofType: .rotate)
        } else {
            layer.removeAllAnimations()
        }
        switch style {
        case .normal:
            image = icon.withRenderingMode(.alwaysTemplate)
            tintColor = normalTintColor
            backgroundColor = .white
        case .highlighted:
            image = icon.withRenderingMode(.alwaysTemplate)
            tintColor = .white
            backgroundColor = highlightColor
        case .spinning:
            if #available(iOS 18.0, *) {
                addSymbolEffect(.rotate, options: .repeating, animated: true)
            } else {
                let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
                rotation.toValue = NSNumber(value: Double.pi * 2)
                rotation.duration = 2
                rotation.isCumulative = true
                rotation.repeatCount = Float.greatestFiniteMagnitude
                rotation.isRemovedOnCompletion = false
                layer.add(rotation, forKey: "rotationAnimation")
            }
            image = icon.withRenderingMode(.alwaysTemplate)
            tintColor = .white
            backgroundColor = highlightColor
        }
    }
}
