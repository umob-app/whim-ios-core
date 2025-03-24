import UIKit
import WhimCore

extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let newDescriptor = fontDescriptor.addingAttributes([.traits: [
            UIFontDescriptor.TraitKey.weight: weight
        ]])
        return UIFont(descriptor: newDescriptor, size: pointSize)
    }
}

extension UIViewController {
    func showToast(message: NSAttributedString, background: UIColor) {
        guard let hostView = UIApplication.shared.delegate?.window??.rootViewController?.view else {
            return
        }
        let toastLabel = UILabel(frame: CGRect(
            x: hostView.frame.size.width / 2 - 125,
            y: hostView.safeAreaInsets.top + WhimTopBarWithCloseButton.UI.buttonPadding,
            width: 250,
            height: WhimTopBarWithCloseButton.UI.buttonSize
        ))
        toastLabel.numberOfLines = 2
        toastLabel.backgroundColor = background
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center
        toastLabel.attributedText = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        
        toastLabel.clipsToBounds = true
        hostView.addSubview(toastLabel)

        UIView.animate(withDuration: 0.5, delay: 2, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: { isCompleted in
            toastLabel.removeFromSuperview()
        })
    }
}

extension NSAttributedString {
    static func make(
        blocks: [Block],
        font: UIFont? = nil,
        textColor: UIColor? = nil,
        symbolColor: UIColor? = nil
    ) -> NSAttributedString {
        let font = font ?? .preferredFont(forTextStyle: .body)
        let textColor = textColor ?? .label
        let symbolColor = symbolColor ?? textColor
        let attributedBlocks: [NSAttributedString] = blocks.map { block in
            switch block {
            case let .text(text):
                return NSAttributedString(
                    string: text,
                    attributes: [
                        .font: font,
                        .foregroundColor: textColor
                    ]
                )
            case let .symbol(symbol):
                let attachment = NSTextAttachment()
                attachment.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(font: font))?
                    .withTintColor(symbolColor)
                return NSAttributedString(attachment: attachment)
            }
        }
        let string = NSMutableAttributedString(string: "")
        attributedBlocks.forEach {
            string.append($0)
        }
        return string
    }

    enum Block {
        case text(String)
        case symbol(String)
    }
}
