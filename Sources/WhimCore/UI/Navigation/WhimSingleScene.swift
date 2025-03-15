import UIKit

/// Scene that represents single possible view controller within whim flow.
public final class WhimSingleScene: WhimScene {
    public let viewController: WhimSceneViewController
    public let relationship = WhimSceneRelationship()

    public init(_ viewController: WhimSceneViewController) {
        self.viewController = viewController
    }

    public func present(scene: WhimScene, animating: WhimSceneAnimatedTransitioning?) {
        // TODO: do we need to pass scene only if `scene.viewController == self.viewController`, or it doesn't even matter here?
        nextSceneResponder?.present(scene: scene, animating: animating)
    }
}

public extension WhimSingleScene {
    convenience init(fullscreen: UIViewController) {
        self.init(.fullscreen(fullscreen))
    }

    convenience init(top: UIViewController, bottom: UIViewController) {
        self.init(.multipart(top: top, bottom: bottom))
    }
}
