import UIKit

// sourcery: Random
public struct VerticalInsets: Equatable {
    public let top: CGFloat
    public let bottom: CGFloat

    public init(top: CGFloat, bottom: CGFloat) {
        self.top = top
        self.bottom = bottom
    }

    public static let zero = VerticalInsets(top: 0, bottom: 0)
}
