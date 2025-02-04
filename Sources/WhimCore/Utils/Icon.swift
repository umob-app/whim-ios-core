import UIKit
import RxSwift

// sourcery: Random
public enum Icon: Hashable, Equatable {
    // sourcery: Random
    public enum Placeholder: Hashable {
        case image(UIImage)
        case asset(String, Bundle?)
        case none

        public static func asset(_ name: String) -> Placeholder {
            .asset(name, nil)
        }

        public var image: UIImage? {
            switch self {
            case let .image(image): return image
            case let .asset(name, bundle): return UIImage(named: name, in: bundle, compatibleWith: nil)
            case .none: return nil
            }
        }

        public var imageOrEmpty: UIImage {
            image ?? .empty
        }
    }

    case url(URL, Placeholder)
    case image(UIImage)
    case asset(String, Bundle?)
    case none

    public static func asset(_ name: String) -> Icon {
        .asset(name, nil)
    }

    public static func url(_ url: URL) -> Icon {
        .url(url, .none)
    }

    public static var empty: Icon {
        .image(UIImage(ciImage: .empty()))
    }
}
