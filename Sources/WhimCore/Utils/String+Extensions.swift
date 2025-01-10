import Foundation

extension String {
    var url: URL? {
        URL(string: self)
    }
}
