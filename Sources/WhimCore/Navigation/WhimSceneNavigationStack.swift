import UIKit

/// Scene that represents ordered navigation stack with view controllers within whim flow.
///
/// Can contain other navigation stacks. The one on the top of the stack is always rendered.
/// Any attempts to pop/push scenes while not being on the top of the stack won't be interrupt the current visible scene.
/// If contains no scenes (i.e. created empty or couldn't add any of provided scenes) will render white fullscreen placeholder.
///
/// It's intended to be subclassed by flow coordinators.
open class WhimSceneNavigationStack: WhimScene {
    /// Fullscreen white scene.
    private static let placeholder: WhimSingleScene = {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .white
        return WhimSingleScene(fullscreen: viewController)
    }()

    /// Ordered scenes stack.
    public final private(set) var scenes: [WhimScene] = []

    /// A parent-child relationship. Publicly available for read-only access.
    public final let relationship = WhimSceneRelationship()
    /// Returns view controller on top of the stack.
    /// If stack is empty will return white fullscreen placeholder.
    public final var viewController: WhimSceneViewController {
        return current.viewController
    }

    private var root: WhimScene {
        return scenes.first ?? Self.placeholder
    }
    private var current: WhimScene {
        return scenes.last ?? Self.placeholder
    }

    public init(_ scenes: [WhimScene]) {
        for scene in scenes {
            add(scene: scene)
        }
    }

    public convenience init(_ head: WhimScene, _ tail: WhimScene...) {
        self.init([head] + tail)
    }

    /// Pushes a scene onto the receiver’s stack, and updates the display if self is also on top of the stack.
    ///
    /// - Parameter scene: The scene to push onto the stack.
    ///   If the scene is already on the navigation stack (this or other), this method does nothing.
    public final func push(scene: WhimScene, animating: WhimSceneAnimatedTransitioning? = WhimSceneAnimatedTransitions.Push()) {
        push(scenes: [scene], animating: animating)
    }

    /// Pushes multiple scenes onto the receiver’s stack, and updates the display if self is also on top of the stack.
    ///
    /// - Parameter scenes: The scenes to push onto the stack.
    ///   If one of the scenes is already on the navigation stack (this or other), it won't be added here again.
    ///   If array is empty, nothing will happen.
    public final func push(scenes: [WhimScene], animating: WhimSceneAnimatedTransitioning? = WhimSceneAnimatedTransitions.Push()) {
        if scenes.map(add).reduce(false, { $0 || $1 }) {
            present(scene: current, animating: animating)
        }
    }

    @discardableResult
    private func add(scene: WhimScene) -> Bool {
        guard canAdd(scene: scene) else {
            return false
        }
        scenes.append(scene)
        scene.relationship.parent = self
        return true
    }

    private func canAdd(scene: WhimScene) -> Bool {
        return scene !== self && scene.relationship.parent == nil && !self.belongs(to: scene)
    }

    /// Pops the top scene from the navigation stack if it's not the root scene,
    /// and updates the display if self is on top of the stack.
    ///
    /// - Returns: The scene that was popped from the stack if it wasn't the root scene.
    ///   Or `nil` if there's only root scene left.
    @discardableResult
    public final func pop(
        animating: WhimSceneAnimatedTransitioning? = WhimSceneAnimatedTransitions.Pop()
    ) -> WhimScene? {
        return pop(lastScenes: 1, animating: animating).popped.first
    }

    /// Pops scenes until the specified scene is at the top of the navigation stack,
    /// and updates the display if self is on top of the stack.
    ///
    /// - Parameter scene: The scene that you want to be at the top of the stack.
    ///   This scene must currently be on the navigation stack.
    /// - Returns: An array containing the scenes that were popped from the stack.
    ///   Or `nil` if scene isn't present on the navigation stack.
    @discardableResult
    public final func pop(
        to scene: WhimScene,
        animating: WhimSceneAnimatedTransitioning? = WhimSceneAnimatedTransitions.Pop()
    ) -> [WhimScene]? {
        guard let indexOfSceneToPop = scenes.firstIndex(where: { $0 === scene }) else {
            return nil
        }
        let lastIndex = scenes.endIndex - 1
        return pop(lastScenes: lastIndex - indexOfSceneToPop, animating: animating).popped
    }

    /// Pops all the scenes on the stack except the root scene, and updates the display if self is on top of the stack.
    ///
    /// - Returns: An array of scenes representing the items that were popped from the stack.
    @discardableResult
    public final func popToRoot(
        animating: WhimSceneAnimatedTransitioning? = WhimSceneAnimatedTransitions.Pop()
    ) -> [WhimScene]? {
        return pop(to: root, animating: animating)
    }

    /// Pops specified number of the last top scenes from the navigation stack,
    /// and updates the display if self is on top of the stack.
    ///
    /// If scene to swap with the last one passed,
    ///
    /// - Parameter lastScenes: Number of last scenes to remove from the stack. It should be less than the size of the stack.
    /// - Returns: A tuple with an array containing the scenes that were popped from the stack.
    ///   Or `[]` if number of scenes to pop is not less than the size of the stack.
    ///   And a boolean value stating whether last scene was swapped or not.
    @discardableResult
    public final func pop(
        lastScenes numberOfScenesToPop: Int,
        andSwapLastWith scene: WhimScene? = nil,
        animating: WhimSceneAnimatedTransitioning? = WhimSceneAnimatedTransitions.Pop()
    ) -> (popped: [WhimScene], swapped: Bool) {
        let numberOfScenesToPopIncludingSwap: Int
        if let scene = scene, canAdd(scene: scene) {
            numberOfScenesToPopIncludingSwap = numberOfScenesToPop + 1
            let numberOfScenesToPopIncludingSwapCondition = scenes.isEmpty
                ? numberOfScenesToPopIncludingSwap == 1
                : numberOfScenesToPopIncludingSwap <= scenes.count
            guard numberOfScenesToPopIncludingSwapCondition, numberOfScenesToPopIncludingSwap > 0 else {
                return ([], false)
            }
        } else {
            numberOfScenesToPopIncludingSwap = numberOfScenesToPop
            guard scenes.count > 1, numberOfScenesToPop < scenes.count, numberOfScenesToPop > 0 else {
                return ([], false)
            }
        }
        let poppedScenes = scenes.suffix(numberOfScenesToPopIncludingSwap)
        if numberOfScenesToPopIncludingSwap <= scenes.count {
            scenes.removeLast(numberOfScenesToPopIncludingSwap)
        }
        for scene in poppedScenes {
            scene.relationship.parent = nil
        }
        if let scene = scene {
            add(scene: scene)
        }
        present(scene: current, animating: animating)
        return (Array(poppedScenes.suffix(numberOfScenesToPop)), numberOfScenesToPopIncludingSwap > numberOfScenesToPop)
    }

    /// Swaps whole stack with the new one, and updates the display if self is on top of the stack.
    /// If stack is empty, will just add new scene.
    ///
    /// - Parameter scene: new scene to replace all scenes.
    /// - Returns:
    ///   - `false` if new scene couldn't be added.
    ///   - `true` if new scene was added, as a new scene if stack was empty or as a replacement for the old one.
    @discardableResult
    public final func swapAll(
        with scene: WhimScene,
        animating: WhimSceneAnimatedTransitioning? = WhimSceneAnimatedTransitions.None()
    ) -> Bool {
        pop(lastScenes: max(scenes.count - 1, 0), andSwapLastWith: scene, animating: animating).swapped
    }

    /// Swaps last scene with the new one, and updates the display if self is on top of the stack.
    /// If stack is empty, will just add new scene.
    ///
    /// - Parameter scene: new scene to replace current last scene.
    /// - Returns:
    ///   - `false` if new scene couldn't be added.
    ///   - `true` if new scene was added, as a new scene if stack was empty or as a replacement for the old one.
    @discardableResult
    public final func swapLast(
        with scene: WhimScene,
        animating: WhimSceneAnimatedTransitioning? = WhimSceneAnimatedTransitions.None()
    ) -> Bool {
        pop(lastScenes: 0, andSwapLastWith: scene, animating: animating).swapped
    }

    /// Asks next responder to present the scene if it's on the top of the stack, no matter how deeply it's nested.
    /// - Note: Do not call this method directly. It's an implementation of `WhimSceneResponder` protocol.
    public func present(scene: WhimScene, animating: WhimSceneAnimatedTransitioning?) {
        if scene.viewController == viewController {
            nextSceneResponder?.present(scene: scene, animating: animating)
        }
    }
}
