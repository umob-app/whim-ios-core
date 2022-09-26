import UIKit
import RxSwift
import RxRelay

/// A view-controller that presents required view-controller within home flow,
/// when asked by someone in the scenes hierarchy.
///
/// It's a root scene by itself.
/// It can be subclassed by main flow coordinator as well as used standalone.
open class HomeSceneContainerViewController: UIViewController, HomeScene {
    public private(set) var rootScene: HomeScene

    public let presentedSceneViewController: ObservableProperty<HomeSceneViewController?>
    private let presentedSceneViewControllerRelay: BehaviorRelay<HomeSceneViewController?>

    public let relationship = HomeSceneRelationship()
    public final var viewController: HomeSceneViewController {
        return rootScene.viewController
    }

    /// Override container view, if you want to keep all navigation there.
    /// Default is root `view` property.
    open var sceneContainerView: UIView {
        return view
    }

    open var sceneContainerViewBackgroundColor: UIColor {
        return .clear
    }

    open override var childForStatusBarStyle: UIViewController? {
        switch viewController {
        case let .fullscreen(fullscreen): return fullscreen
        case let .multipart(top, _): return top
        }
    }

    public init(initial: HomeScene) {
        rootScene = initial
        presentedSceneViewControllerRelay = BehaviorRelay(value: nil)
        presentedSceneViewController = ObservableProperty(presentedSceneViewControllerRelay)

        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        rootScene.relationship.parent = self
        present(scene: rootScene)
    }

    /// Set new root scene with or without animation.
    /// - Parameters:
    ///   - root: New root scene for this container.
    ///   - animating: Animation to be performed, or nil for immediate transition.
    /// - Returns:
    ///   * `true` if transition was performed successfully, or when setting current root.
    ///   * `false` if transition can't be performed because new root is invalid:
    ///     i.e. already has a different parent or if new root is this container itself.
    @discardableResult
    public final func set(root: HomeScene, animating: HomeSceneAnimatedTransitioning? = nil) -> Bool {
        guard root !== rootScene else {
            return true
        }
        guard root !== self, root.relationship.parent == nil else {
            return false
        }
        rootScene.relationship.parent = nil
        rootScene = root

        guard isViewLoaded else {
            return true
        }
        rootScene.relationship.parent = self
        present(scene: rootScene, animating: animating)

        return true
    }

    public final func present(scene: HomeScene, animating: HomeSceneAnimatedTransitioning?) {
        guard scene.belongs(to: rootScene) else {
            return
        }
        guard presentedSceneViewControllerRelay.value != scene.viewController else {
            return
        }
        prepareBeforeTransition(scene.viewController)
        let from  = presentedSceneViewControllerRelay.value
        presentedSceneViewControllerRelay.accept(scene.viewController)
        transition(
            from: from,
            to: scene.viewController,
            animating: animating ?? HomeSceneAnimatedTransitions.None()
        )
    }

    private func prepareBeforeTransition(_ viewController: HomeSceneViewController) {
        for child in viewController.viewControllers {
            if child.parent != nil || (child.isViewLoaded && child.view.superview != nil) {
                child.willMove(toParent: nil)
                child.view.removeFromSuperview()
                child.removeFromParent()
            }
        }
    }

    private func transition(from: HomeSceneViewController?, to: HomeSceneViewController, animating: HomeSceneAnimatedTransitioning) {
        let children = from?.viewControllers ?? []
        children.forEach { $0.willMove(toParent: nil) }
        to.viewControllers.forEach(addChild)
        // We're currently setting different background color for the container view in the landing menu,
        // however there might be more scenes to do so.
        //
        // And to avoid some scenes forgetting to reset it to original state and to not require to do it manually everywhere,
        // it seems more convenient to do it here automatically.
        //
        // However if done too early (before transition), it will reset container state before source scene is hidden,
        // and if done too late (after transition), it will reset container state after newely shown scene has applied its own.
        //
        // So to make container reset smoother, we start it before transition and animate it during transition duration ¯\_(ツ)_/¯
        resetSceneContainerView(during: animating.duration)
        // There might be funky situations, when user initiates new transition while old hasn't finished yet.
        //
        // Usually it's harmless, but can be that user tries to dismiss currently opening scene which hasn't finished opening.
        // It will lead to two simultaneous animations A -> B, B -> A:
        // 1. 'A' will prepare to be removed as a child to add 'B'.
        // 2. in the middle of this, 'B' will be preapred to be removed to add 'A'.
        // 3. once 'A' transition ended, it will completely remove 'B', while 'B' is already in progress.
        // 4. once 'B' transition ended, it will completely remove 'A', while also being removed in previous step.
        // By the end of both animations, both scenes are removed from the UIKit stack.
        //
        // To prevent this, we:
        // - do not remove `from` children,
        //   if it turns out that it's the same instance as `presentedSceneViewController` by the end of transiton
        // - turn off any user interactions up until transition in progress is fully complete,
        //   this one is mostly to prevent user opening few same scenes if they quickly tap on a button.
        sceneContainerView.isUserInteractionEnabled = false
        animating.transition(from: from, to: to, container: sceneContainerView) { [weak self] _ in
            guard let self = self else { return }
            defer {
                self.sceneContainerView.isUserInteractionEnabled = true
                self.setNeedsStatusBarAppearanceUpdate()
            }
            guard self.presentedSceneViewControllerRelay.value != from else {
                return
            }
            for child in children {
                child.view.removeFromSuperview()
                child.removeFromParent()
            }
            to.viewControllers.forEach { $0.didMove(toParent: self) }
        }
    }

    private func resetSceneContainerView(during duration: TimeInterval) {
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseIn, animations: { [weak self] in
            guard let self = self else { return }
            self.sceneContainerView.transform = .identity
            self.sceneContainerView.backgroundColor = self.sceneContainerViewBackgroundColor
        })
    }
}
