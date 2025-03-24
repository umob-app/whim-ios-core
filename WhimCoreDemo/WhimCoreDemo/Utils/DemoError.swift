import Foundation

enum DemoError: Error, Equatable, Hashable {
    enum GeoJSON: Equatable, Hashable {
        case missingResource
        case wrongFormat
    }

    case geo(GeoJSON)
    case cancelled
    case other(NSError)
    case unknown
    // etc...
}
