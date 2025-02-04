import Foundation
import UIKit

func image(named: String) -> UIImage? {
    UIImage(named: named, in: Bundle.module, compatibleWith: nil)
}
