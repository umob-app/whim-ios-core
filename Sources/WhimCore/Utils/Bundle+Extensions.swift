import Foundation
import UIKit

extension WhimCore {
    static func image(named: String) -> UIImage? {
        return UIImage(named: named, in: Bundle.module, compatibleWith: nil)
    }
}
