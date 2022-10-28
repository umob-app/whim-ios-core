import UIKit

extension UIImage {
    /// Removes transparent pixels
    public func cropAlpha() -> UIImage? {
        guard let cgImage = cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel: Int = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo),
              let ptr = context.data?.assumingMemoryBound(to: UInt8.self) else {
            return self
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX: Int = 0
        var maxY: Int = 0

        for x in 1 ..< width {
            for y in 1 ..< height {
                let i = bytesPerRow * Int(y) + bytesPerPixel * Int(x)
                let a = CGFloat(ptr[i + 3]) / 255.0

                if a > 0 {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }

        let rect = CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX),
            height: CGFloat(maxY - minY)
        )
        let imageScale: CGFloat = scale
        let croppedImage = cgImage.cropping(to: rect)!
        let ret = UIImage(cgImage: croppedImage, scale: imageScale, orientation: imageOrientation)

        return ret
    }

    public var hasAlpha: Bool {
        guard let alphaInfo = self.cgImage?.alphaInfo else {
            return false
        }

        return alphaInfo != CGImageAlphaInfo.none
            && alphaInfo != CGImageAlphaInfo.noneSkipFirst
            && alphaInfo != CGImageAlphaInfo.noneSkipLast
    }
}


