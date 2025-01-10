import UIKit
import RxSwift
import SDWebImage

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

public extension Icon {
    /// - Returns: ObservableProperty with either existing image, or empty image in case loading failed.
    ///
    /// When loading with url, initial image will be immediately either placeholder or an empty image,
    /// after loading with url, requested image will come or in case of error will keep initial one.
    func imageOrEmpty(transform: @escaping (UIImage) -> UIImage = { $0 }) -> ObservableProperty<UIImage> {
        switch self {
        case let .url(url, placeholder):
            return ObservableProperty(initial: placeholder.imageOrEmpty, then: Observable.create { observer in
                let cancellable = SDWebImageManager.shared
                    .loadImage(with: url, options: SDWebImageOptions(), progress: nil) { image, data, error, cacheType, finished, url in
                        image.map(transform).map(observer.onNext)
                        if finished {
                            observer.onCompleted()
                        }
                    }
                return Disposables.create {
                    cancellable?.cancel()
                }
            })
        case let .image(image):
            return ObservableProperty(transform(image))
        case let .asset(name, bundle):
            return ObservableProperty(transform(UIImage(named: name, in: bundle, compatibleWith: nil) ?? .empty))
        case .none:
            return ObservableProperty(transform(.empty))
        }
    }
}

extension UIImageView {
    func setImage(
        with icon: Icon?,
        imageTransform: ImageTransformer = .none,
        refreshCached: Bool = true,
        avoidAutoSetImage: Bool = false,
        successfulCallback: ((UIImage?) -> Void)? = nil,
        errorCallback: ((Error) -> Void)? = nil
    ) {
        switch icon {
        case let .url(url, placeholder):
            setImage(
                with: url,
                placeholderImage: placeholder.image,
                imageTransform: imageTransform,
                refreshCached: refreshCached,
                avoidAutoSetImage: avoidAutoSetImage,
                successfulCallback: successfulCallback,
                errorCallback: errorCallback
            )
        case let .image(image):
            self.image = image
            successfulCallback?(self.image)
        case let .asset(name, bundle):
            self.image = UIImage(named: name, in: bundle, compatibleWith: nil)
            successfulCallback?(self.image)
        case .none?, nil:
            self.image = nil
            successfulCallback?(self.image)
        }
    }
}
