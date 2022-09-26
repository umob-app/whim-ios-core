import UIKit

/// Scene that represents single possible view controller within home flow.
public final class HomeSingleScene: HomeScene {
    public let viewController: HomeSceneViewController
    public let relationship = HomeSceneRelationship()

    public init(_ viewController: HomeSceneViewController) {
        self.viewController = viewController
    }

    public func present(scene: HomeScene, animating: HomeSceneAnimatedTransitioning?) {
        // TODO: do we need to pass scene only if `scene.viewController == self.viewController`, or it doesn't even matter here?
        nextSceneResponder?.present(scene: scene, animating: animating)
    }
}

public extension HomeSingleScene {
    convenience init(fullscreen: UIViewController) {
        self.init(.fullscreen(fullscreen))
    }

    convenience init(top: UIViewController, bottom: UIViewController) {
        self.init(.multipart(top: top, bottom: bottom))
    }
}
