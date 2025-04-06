import UIKit

// MARK: - Responder

/// Responder in chain, which defines its next receiver and delegates presentation of a scene within whim flow.
public protocol WhimSceneResponder: AnyObject {
    var nextSceneResponder: WhimSceneResponder? { get }

    /// Implement scene presentation here.
    /// - Note: do not call this method directly unless you're implementing custom navigation stack/container.
    func present(scene: WhimScene, animating: WhimSceneAnimatedTransitioning?)
}

public extension WhimSceneResponder {
    func present(scene: WhimScene) {
        present(scene: scene, animating: nil)
    }
}

// MARK: - Relationship

/// Wrapper for scene parent-child relationship.
/// Reads are public, writes are internal to the library, so that relationship couldn't be compromised from the outside.
public final class WhimSceneRelationship {
    init() {}

    public internal(set) weak var parent: WhimScene?
}

// MARK: - Scene

/// Scene that can be nested inside hierarchical structure.
public protocol WhimScene: WhimSceneResponder {
    var relationship: WhimSceneRelationship { get }
    var viewController: WhimSceneViewController { get }
}

/// Parent is the next responder-chain receiver by default.
public extension WhimScene {
    var nextSceneResponder: WhimSceneResponder? { relationship.parent }

    /// Checks if self belongs to the hierarchy of given scene.
    /// - Parameter scene: A scene to check against.
    /// - Returns: `true` if given scene is self or one of self's parents on any nesting level.
    func belongs(to scene: WhimScene) -> Bool {
        guard scene !== self else {
            return true
        }
        guard let parent = relationship.parent else {
            return false
        }
        return scene === parent || parent.belongs(to: scene)
    }
}

public extension WhimScene {
    var anyUIViewController: UIViewController {
        viewController.fullscreenOrBottom
    }
}
