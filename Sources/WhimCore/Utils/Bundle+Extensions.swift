import Foundation

extension Bundle {
    private class CurrentBundle {}

    static var framework: Bundle {
        return Bundle(for: CurrentBundle.self)
    }

    static var resources: Bundle? {
        return Bundle.framework.path(forResource: "WhimCoreResources", ofType: "bundle").flatMap(Bundle.init)
    }
}

func image(named: String) -> UIImage? {
    return UIImage(named: named, in: Bundle.resources, compatibleWith: nil)
}
