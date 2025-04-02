import UIKit

// MARK: - Abstraction

public protocol WhimSceneAnimatedTransitioning {
    typealias Completion = (Bool) -> Void

    /// Called when transition is happening from one controller to the other inside container view.
    ///
    /// You should add `to`'s view as subview to the `container` view manually here.
    ///
    /// You should always call `completion` to finish transition.
    /// If animating transition with `UIView.animate`, call this callback when animation completes.
    ///
    /// - Parameters:
    ///   - from: Optional view controller from which transition is happening. If `nil`, then there was no prior controller.
    ///   - to: view ontroller which is about to be shown.
    ///   - container: Container view which contains both `from` and `to` controllers' views.
    ///   - completion: Callback which should be called when transition is finished either successfully or not.
    func transition(from: WhimSceneViewController?, to: WhimSceneViewController, container: UIView, completion: @escaping Completion)
}

extension WhimSceneAnimatedTransitioning {
    var duration: TimeInterval { 0.3 }
}

// MARK: - Animations

public enum WhimSceneAnimatedTransitions {}

extension WhimSceneAnimatedTransitions {
    public struct Push: WhimSceneAnimatedTransitioning {
        public init() {}

        public func transition(from: WhimSceneViewController?, to: WhimSceneViewController, container: UIView, completion: @escaping Completion) {
            to.disableTranslatingAutoresizingMaskIntoConstraints()

            guard from?.viewControllers.isEmpty != true else {
                to.viewControllers.map(\.view).forEach(container.addSubview)
                finalPositionConstraints(for: to, in: container).activate()
                return completion(true)
            }

            to.viewControllers.map(\.view).forEach(container.addSubview)
            let constraints = finalPositionConstraints(for: to, in: container, dx: container.frame.width).activate()
            container.layoutIfNeeded()

            constraints.offsetAsSinglePiece(dx: 0, dy: 0)
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
                from?.update(keyPath: \.view.transform, with: CGAffineTransform(translationX: -container.frame.width, y: 0))
                container.layoutIfNeeded()
            }, completion: { finished in
                completion(finished)
                from?.update(keyPath: \.view.transform, with: .identity)
            })
        }
    }
}

extension WhimSceneAnimatedTransitions {
    public struct Pop: WhimSceneAnimatedTransitioning {
        public init() {}

        public func transition(from: WhimSceneViewController?, to: WhimSceneViewController, container: UIView, completion: @escaping Completion) {
            to.disableTranslatingAutoresizingMaskIntoConstraints()

            guard from?.viewControllers.isEmpty != true else {
                to.viewControllers.map(\.view).forEach(container.addSubview)
                finalPositionConstraints(for: to, in: container).activate()
                return completion(true)
            }

            to.viewControllers.map(\.view).forEach(container.addSubview)
            let constraints = finalPositionConstraints(for: to, in: container, dx: -container.frame.width).activate()
            container.layoutIfNeeded()

            constraints.offsetAsSinglePiece(dx: 0, dy: 0)
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
                from?.update(keyPath: \.view.transform, with: CGAffineTransform(translationX: container.frame.width, y: 0))
                container.layoutIfNeeded()
            }, completion: { finished in
                completion(finished)
                from?.update(keyPath: \.view.transform, with: .identity)
            })
        }
    }
}

extension WhimSceneAnimatedTransitions {
    /// Complex modal presentation with multiple modes respecting all supported whim-scene-view-controller variations.
    ///
    /// Here's a scheme describing transitions of different variations for different modes:
    /// ```
    /// 🁣 - multipart;
    /// 🁢 - fullscreen;
    /// ↑/↓ - slides up/down;
    /// transition from → to;
    ///
    /// present (`to` overlaps `from` within z-axis):
    /// ↑   ↓              ↓   ↓
    /// 🁣 → 🁣     🁣 → 🁢     🁢 → 🁣     🁢 → 🁢
    /// ↓   ↑        ↑         ↑         ↑
    ///
    /// dismiss (`from` overlaps `to` within z-axis):
    /// ↑   ↓     ↑        ↓         ↓
    /// 🁣 → 🁣     🁣 → 🁢     🁢 → 🁣     🁢 → 🁢
    /// ↓   ↑     ↓  ↑
    ///
    /// swap (`to` overlaps `from` within z-axis):
    /// ↑   ↓     ↑        ↓   ↓     ↓
    /// 🁣 → 🁣     🁣 → 🁢     🁢 → 🁣     🁢 → 🁢
    /// ↓   ↑     ↓  ↑         ↑         ↑
    /// ```
    public struct Modal: WhimSceneAnimatedTransitioning {
        public enum Mode: Equatable {
            case present, dismiss, swap
        }

        private let mode: Mode

        public init(_ mode: Mode) {
            self.mode = mode
        }

        public func transition(from: WhimSceneViewController?, to: WhimSceneViewController, container: UIView, completion: @escaping Completion) {
            to.disableTranslatingAutoresizingMaskIntoConstraints()

            guard let from = from else {
                to.viewControllers.map(\.view).forEach(container.addSubview)
                finalPositionConstraints(for: to, in: container).activate()
                return completion(true)
            }
            let isFromFullscreen = from.isFullscreen
            let isToFullscreen = to.isFullscreen
            let mode = self.mode
            // we need to calculate original size first to know at which distance, to put both sides from the edges,
            // however it means that `to` view controller might appear in its final position for a moment.
            // to avoid this glitch, we set its alpha to 0 and once it is in its intial state we rollback alpha to 1.
            to.viewControllers.map(\.view).forEach(container.addSubview)
            to.update(keyPath: \.view.alpha, with: 0)
            let toConstraints = finalPositionConstraints(for: to, in: container).activate()
            container.layoutIfNeeded()

            switch mode {
            case .present, .swap:
                to.map(\.view).map(container.bringSubviewToFront)
            case .dismiss:
                from.map(\.view).map(container.bringSubviewToFront)
            }

            switch toConstraints {
            case let .fullscreen(fullscreen):
                if mode != .dismiss || !isFromFullscreen {
                    fullscreen.offset(dx: 0, dy: container.frame.height)
                }
            case let .multipart(top, bottom):
                if let (topVC, bottomVC) = to.multipart, mode != .dismiss || !isFromFullscreen {
                    top.top.constant = -topVC.view.frame.height
                    bottom.bottom.constant = -bottomVC.view.frame.height
                }
            }
            to.update(keyPath: \.view.alpha, with: 1)
            container.layoutIfNeeded()

            toConstraints.offsetAsSinglePiece(dx: 0, dy: 0)
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
                from.update(
                    keyPath: \.view.transform,
                    with: from.map(
                        fullscreen: { fullscreen in
                            mode == .present && isToFullscreen ? 0 : fullscreen.view.frame.height
                        },
                        multipart: { top, bottom in
                            mode == .present && isToFullscreen ? (0, 0) : (-top.view.frame.height, bottom.view.frame.height)
                        }
                    )
                    .map { CGAffineTransform(translationX: 0, y: $0) }
                )
                container.layoutIfNeeded()
            }, completion: { finished in
                completion(finished)
                from.update(keyPath: \.view.transform, with: .identity)
            })
        }
    }
}

extension WhimSceneAnimatedTransitions {
    public struct Fade: WhimSceneAnimatedTransitioning {
        public init() {}

        public func transition(from: WhimSceneViewController?, to: WhimSceneViewController, container: UIView, completion: @escaping Completion) {
            to.disableTranslatingAutoresizingMaskIntoConstraints()

            guard from?.viewControllers.isEmpty != true else {
                to.viewControllers.map(\.view).forEach(container.addSubview)
                finalPositionConstraints(for: to, in: container).activate()
                return completion(true)
            }

            to.update(keyPath: \.view.alpha, with: 0)
            to.viewControllers.map(\.view).forEach(container.addSubview)
            finalPositionConstraints(for: to, in: container).activate()
            container.layoutIfNeeded()

            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
                from?.update(keyPath: \.view.alpha, with: 0)
                to.update(keyPath: \.view.alpha, with: 1)
            }, completion: { finished in
                completion(finished)
                from?.update(keyPath: \.view.alpha, with: 1)
            })
        }
    }
}

extension WhimSceneAnimatedTransitions {
    public struct None: WhimSceneAnimatedTransitioning {
        public init() {}

        public func transition(from: WhimSceneViewController?, to: WhimSceneViewController, container: UIView, completion: @escaping Completion) {
            to.disableTranslatingAutoresizingMaskIntoConstraints()
            to.viewControllers.map(\.view).forEach(container.addSubview)
            finalPositionConstraints(for: to, in: container).activate()
            completion(true)
        }
    }
}

extension WhimSceneAnimatedTransitions {
    public class Circular: NSObject, WhimSceneAnimatedTransitioning, CAAnimationDelegate {
        public enum Mode: Equatable {
            case present, dismiss
        }

        private let mode: Mode
        private let originRect: CGRect
        private var completion: Completion?
        private var maskLayerView: UIView?

        public init(_ mode: Mode, originRect: CGRect) {
            self.mode = mode
            self.originRect = originRect
        }

        public func transition(from: WhimSceneViewController?, to: WhimSceneViewController, container: UIView, completion: @escaping Completion) {
            self.completion = completion
            to.disableTranslatingAutoresizingMaskIntoConstraints()

            guard let from = from else {
                to.viewControllers.map(\.view).forEach(container.addSubview)
                finalPositionConstraints(for: to, in: container).activate()
                return completion(true)
            }

            let mode = self.mode

            to.viewControllers.map(\.view).forEach(container.addSubview)
            _ = finalPositionConstraints(for: to, in: container).activate()
            container.layoutIfNeeded()

            switch mode {
            case .present:
                to.map(\.view).map(container.bringSubviewToFront)
                maskLayerView = container.subviews.last
            case .dismiss:
                from.map(\.view).map(container.bringSubviewToFront)
                maskLayerView = from.viewControllers.last?.view
            }

            guard let maskLayerView = maskLayerView else {
                return completion(true)
            }

            let fullHeight = container.bounds.height * 1.2
            let extremePoint = CGPoint(x: originRect.midX, y: originRect.midY - fullHeight)
            let radius = sqrt((extremePoint.x * extremePoint.x) + (extremePoint.y * extremePoint.y))

            let circleMaskPathInitial: UIBezierPath
            let circleMaskPathFinal: UIBezierPath

            switch mode {
            case .present:
                circleMaskPathInitial = UIBezierPath(ovalIn: originRect)
                circleMaskPathFinal = UIBezierPath(ovalIn: originRect.insetBy(dx: -radius, dy: -radius))
            case .dismiss:
                circleMaskPathInitial = UIBezierPath(ovalIn: originRect.insetBy(dx: -radius, dy: -radius))
                circleMaskPathFinal = UIBezierPath(ovalIn: originRect)
            }

            let maskLayer = CAShapeLayer()
            maskLayer.path = circleMaskPathFinal.cgPath
            maskLayerView.layer.mask = maskLayer

            let maskLayerAnimation = CABasicAnimation(keyPath: "path")
            maskLayerAnimation.fromValue = circleMaskPathInitial.cgPath
            maskLayerAnimation.toValue = circleMaskPathFinal.cgPath
            maskLayerAnimation.duration = duration
            maskLayerAnimation.delegate = self

            maskLayer.add(maskLayerAnimation, forKey: "path")
        }

        public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
            maskLayerView?.layer.mask = nil
            maskLayerView = nil
            completion?(flag)
            completion = nil
        }
    }
}

// MARK: - Utils

private extension WhimSceneAnimatedTransitioning {
    @discardableResult
    func finalPositionConstraints(
        for whimViewController: WhimSceneViewController,
        in container: UIView,
        minTopHeight: CGFloat = 1,
        minBottomHeight: CGFloat = 1,
        minTopBottomSpace: CGFloat = 0,
        dx: CGFloat = 0,
        dy: CGFloat = 0
    ) -> WhimSceneViewControllerConstraints {
        return whimViewController.map(
            fullscreen: { fullscreen in
                return WhimSceneAnimatedTransitionConstraints(
                    top: fullscreen.view.topAnchor.constraint(equalTo: container.topAnchor),
                    bottom: container.bottomAnchor.constraint(equalTo: fullscreen.view.bottomAnchor),
                    leading: fullscreen.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    trailing: container.trailingAnchor.constraint(equalTo: fullscreen.view.trailingAnchor),
                    height: nil
                )
            },
            multipart: { top, bottom in
                let topBottom = bottom.view.topAnchor.constraint(greaterThanOrEqualTo: top.view.bottomAnchor, constant: minTopBottomSpace)
                return (
                    top: WhimSceneAnimatedTransitionConstraints(
                        top: top.view.topAnchor.constraint(equalTo: container.topAnchor),
                        bottom: topBottom,
                        leading: top.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                        trailing: container.trailingAnchor.constraint(equalTo: top.view.trailingAnchor),
                        height: top.view.heightAnchor.constraint(greaterThanOrEqualToConstant: minTopHeight)
                    ),
                    bottom: WhimSceneAnimatedTransitionConstraints(
                        top: topBottom,
                        bottom: container.bottomAnchor.constraint(equalTo: bottom.view.bottomAnchor),
                        leading: bottom.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                        trailing: container.trailingAnchor.constraint(equalTo: bottom.view.trailingAnchor),
                        height: bottom.view.heightAnchor.constraint(greaterThanOrEqualToConstant: minBottomHeight)
                    )
                )
            }
        )
        .offsetAsSinglePiece(dx: dx, dy: dy)
    }
}

private struct WhimSceneAnimatedTransitionConstraints {
    let top: NSLayoutConstraint
    let bottom: NSLayoutConstraint
    let leading: NSLayoutConstraint
    let trailing: NSLayoutConstraint

    let height: NSLayoutConstraint?

    var all: [NSLayoutConstraint] {
        return [top, bottom, leading, trailing] + (height.map { [$0] } ?? [])
    }

    @discardableResult
    func offset(dx: CGFloat, dy: CGFloat) -> WhimSceneAnimatedTransitionConstraints {
        top.constant = dy
        bottom.constant = -dy
        leading.constant = dx
        trailing.constant = -dx
        return self
    }
}

private typealias WhimSceneViewControllerConstraints = WhimSceneViewControllerValue<WhimSceneAnimatedTransitionConstraints>

private extension WhimSceneViewControllerConstraints {
    var constraints: [NSLayoutConstraint] {
        switch self {
        case let .fullscreen(fullscreen): return fullscreen.all
        case let .multipart(top, bottom): return Array(Set(top.all + bottom.all))
        }
    }

    @discardableResult
    func activate() -> WhimSceneViewControllerConstraints {
        NSLayoutConstraint.activate(constraints)
        return self
    }

    @discardableResult
    func deactivate() -> WhimSceneViewControllerConstraints {
        NSLayoutConstraint.deactivate(constraints)
        return self
    }

    @discardableResult
    func offsetAsSinglePiece(dx: CGFloat, dy: CGFloat) -> WhimSceneViewControllerConstraints {
        switch self {
        case let .fullscreen(fullscreen):
            fullscreen.offset(dx: dx, dy: dy)
        case let .multipart(top, bottom):
            top.top.constant = dy
            top.leading.constant = dx
            top.trailing.constant = -dx
            // not updating top's bottom and bottom's top constraints here, as they serve as a gap between each other,
            // however their opposite sides serve as sticky points to anchor them to the container.
            bottom.leading.constant = dx
            bottom.trailing.constant = -dx
            bottom.bottom.constant = -dy
        }
        return self
    }
}

private extension WhimSceneViewController {
    func disableTranslatingAutoresizingMaskIntoConstraints() {
        update(keyPath: \.view.translatesAutoresizingMaskIntoConstraints, with: false)
    }
}
