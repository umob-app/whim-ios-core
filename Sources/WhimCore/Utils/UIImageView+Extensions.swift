import UIKit
import SDWebImage

extension UIImageView {
    func setImage(
        with url: URL?,
        placeholderImage: UIImage? = nil,
        imageTransform: ImageTransformer = .none,
        refreshCached: Bool = true,
        avoidAutoSetImage: Bool = false,
        successfulCallback: ((UIImage?) -> Void)? = nil,
        errorCallback: ((Error) -> Void)? = nil
    ) {
        let options = [
            refreshCached ? SDWebImageOptions.refreshCached : nil,
            avoidAutoSetImage ? SDWebImageOptions.avoidAutoSetImage : nil
        ]
        .compactMap { $0 }
        .reduce(into: SDWebImageOptions()) { acc, option in
            acc.insert(option)
        }
        sd_setImage(
            with: url,
            placeholderImage: placeholderImage,
            options: options,
            context: imageTransform.context,
            progress: nil
        ) { (image, error, _, _) in
            if let error = error {
                errorCallback?(error)
                return
            }
            successfulCallback?(image)
        }
    }
}

enum ImageTransformer {
    case none
    case cropAlpha
}

extension ImageTransformer {
    var context: [SDWebImageContextOption: SDImageTransformer]? {
        switch self {
        case .none:
            return nil
        case .cropAlpha:
            return [.imageTransformer: ImageAlphaCroppingTransformer()]
        }
    }
}

class ImageAlphaCroppingTransformer: NSObject, SDImageTransformer {
    var transformerKey: String { "AlphaCroppingTransformer" }

    func transformedImage(with image: UIImage, forKey key: String) -> UIImage? {
        image.cropAlpha()
    }
}
