//
//  UIImageViewExtensions.swift
//  Pods
//
//  Created by Ruben Exposito Marin on 9/8/18.
//

import UIKit
import SDWebImage

public extension UIImageView {
    private static var cacheSVG = [String: String]()

    func loadingAnimation() {
        let animation = WhimCustomAnimations.whimSpinAnimation()
        layer.add(animation, forKey: "animation")
    }    

    func setImage(with url: URL?,
                  placeholderImage: UIImage? = nil,
                  imageTransform: ImageTransformer = .none,
                  refreshCached: Bool = true,
                  avoidAutoSetImage: Bool = false,
                  successfulCallback: ((UIImage?) -> Void)? = nil,
                  errorCallback: ((Error) -> Void)? = nil) {
        let options = [
            refreshCached ? SDWebImageOptions.refreshCached : nil,
            avoidAutoSetImage ? SDWebImageOptions.avoidAutoSetImage : nil
        ]
        .compacted
        .reduce(into: SDWebImageOptions()) { acc, option in
            acc.insert(option)
        }

        sd_setImage(
            with: url,
            placeholderImage: placeholderImage,
            options: options,
            context: imageTransform.context,
            progress: nil) { (image, error, _, _) in
            if let error = error {
                errorCallback?(error)
                return
            }

            successfulCallback?(image)
        }
    }

    func setImage(with string: String?,
                  placeholderImage: UIImage? = nil,
                  successfulCallback: ((UIImage?) -> Void)? = nil,
                  errorCallback: ((Error) -> Void)? = nil) {
        setImage(with: string?.url, placeholderImage: placeholderImage, successfulCallback: successfulCallback, errorCallback: errorCallback)
    }

    func cancelCurrentImageLoad() {
        sd_cancelCurrentImageLoad()
    }

    func circleShape() {
        let radius = bounds.width / 2
        layer.cornerRadius = radius
        layer.masksToBounds = true
    }

    static func setSVGImage(with url: URL, completion: ((String?) -> ())? = nil) {
        if let cache = UIImageView.cacheSVG[url.absoluteString] {
            completion?(cache)
            return
        }

        DispatchQueue.global(qos: .utility).async {
            guard let svgString = try? String(contentsOf: url, encoding: String.Encoding.utf8) else {
                completion?(nil)
                return
            }

            DispatchQueue.main.async {
                UIImageView.cacheSVG[url.absoluteString] = svgString
                completion?(svgString)
            }
        }
    }
}

public enum ImageTransformer {
    case none
    case cropAlpha
}

public extension ImageTransformer {
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
