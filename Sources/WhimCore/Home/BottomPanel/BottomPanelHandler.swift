import UIKit
import RxSwift
import RxRelay
import WhimUtils

/// Core mechanics is taken from [PullUpController](https://github.com/MarioIannotta/PullUpController) and adapted to our needs.
///
/// We make use of composition by splitting logic (`BottomPanelHandler`) from the UI interface (`BottomPanel`)
/// instead of inheriting some base view controller.
/// And sometimes we might want to inherit some other base view controllers as well ¯\\_(ツ)_/¯
///
/// Bottom panel handler, once assigned bottom panel (at any point in the program),
/// will subscribe to its view controller lifecycle updates and will refresh UI on every `viewDidAppear` invocation.
///
/// The reason for this is simple - we heavily rely on autolayout here.
/// And once view controller is used within some navigation stack, it can be added and removed multiple times as we navigate.
/// It means that constraints will change and bottom panel handler needs up-to-date constraints to perform its work.
public final class BottomPanelHandler: ObservableConvertibleType {
    /// Represents event coming from the handler.
    public enum Event: Equatable {
        /// Represents bottom panel status once event is triggered.
        /// - If only one sticky point is provided for the bottom panel, will always contain `collapsed`¹ status.
        /// - If two sticky points are provided for the bottom panel, will contain either `collapsed`¹ or `expanded`¹.
        /// - If three and more sticky points are provided for the bottom panel, will contain full set of statuses accordingly:
        ///   `collapsed`¹ - `middle`* - `expanded`¹
        public enum Status: Equatable { case collapsed, expanded, middle }

        case didMove(BottomPanelPoint, Status)
        case didDrag(BottomPanelPoint)

        /// Is triggered when sticky points are re-calculated.
        /// Will mostly happen on `viewDidAppear`, when sizes of the bottom panel and its container are known.
        /// Can be also triggered by removing bottom panel reference from the handler, or by calling `refresh` method manually.
        ///
        /// Sticky points are sorted in ascending order by their calculated `relative` values (same as for the panel),
        /// where first values are closer the top and last - closer to the bottom.
        case didRefreshStickyPoints([BottomPanelPoint])
    }

    private let events = PublishRelay<Event>()
    private var disposeBag = DisposeBag()
    private var availableArea: BottomPanelAvailableArea = .zero
    private var topConstraint: NSLayoutConstraint?
    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var initialScrollViewContentOffset: CGPoint = .zero
    /// Calculated sticky points, sorted by `relative` value in ascending order.
    public private(set) var stickyPoints: [BottomPanelPoint] = [] {
        didSet {
            events.accept(.didRefreshStickyPoints(stickyPoints))
        }
    }
    /// Used to rollback bottom panel to its previous sticky point during next refresh cycle (i.e. during next `viewDidAppear`).
    private var lastUsedStickyPoint: BottomPanelPoint.Relative?
    private var initialBottomPanelPoint: BottomPanelPoint?

    // MARK: Public Interface

    public init(bottomPanel: BottomPanel) {
        self.bottomPanel = bottomPanel
        setup()
    }

    /// Weak readonly reference to the bottom panel.
    ///
    /// No matter when it's set during bottom panel's lifecycle,
    /// it'll first try to figure out whether bottom panel is already presented on the screen,
    /// and if yes, then it will apply bottom panel's configs immediately.
    /// It will also subscribe to bottom panel's lifecycle and will refresh it every time `viewDidAppear` is invoked.
    public private(set) weak var bottomPanel: BottomPanel?

    /// State whether bottom panel isn't moving,
    /// by comparing its current point against one of the sticky points and gesture recognizer's state.
    public var isIdle: Bool {
        guard let state = bottomPanel?.bottomPanelScrollView?.panGestureRecognizer.state else {
            return false
        }
        let isDragging = state == .began || state == .changed
        return !isDragging && stickyPoints.contains { $0.relative.value == topConstraint?.constant }
    }

    public var currentStatus: Event.Status? {
        return stickyPoints.first(where: { $0.relative == lastUsedStickyPoint }).map(pointStatus)
    }

    /// Expand bottom panel animated or immediately.
    ///
    /// Will trigger both `willMove` and `didMove` events no matter if transition is animated or not.
    /// Will not trigger any events if already in requested position.
    public func expand(animated: Bool = true) {
        if let stickyPoint = stickyPoints.first?.relative, lastUsedStickyPoint != stickyPoint {
            setTopOffset(stickyPoint, isGesture: false, animationDuration: animated ? 0.5 : .zero, allowBounce: animated)
        }
    }

    /// Collapse bottom panel animated or immediately.
    ///
    /// Will trigger both `willMove` and `didMove` events no matter if transition is animated or not.
    /// Will not trigger any events if already in requested position.
    public func collapse(animated: Bool = true) {
        if let stickyPoint = stickyPoints.last?.relative, lastUsedStickyPoint != stickyPoint {
            setTopOffset(stickyPoint, isGesture: false, animationDuration: animated ? 0.5 : .zero, allowBounce: animated)
        }
    }

    /// Move panel to initialStickyPoint animated or immediately.
    ///
    /// Will trigger both `willMove` and `didMove` events no matter if transition is animated or not.
    /// Will not trigger any events if already in requested position.
    public func moveToInitialStickyPoint(animated: Bool = true) {
        if let stickyPoint = initialBottomPanelPoint?.relative, lastUsedStickyPoint != stickyPoint {
            setTopOffset(stickyPoint, isGesture: false, animationDuration: animated ? 0.5 : .zero, allowBounce: animated)
        }
    }

    /// Subscribe to events regarding bottom panel.
    /// - Parameter onEvent: subscription block that receives events.
    /// - Returns: disposable in case subscription needs to be manually terminated.
    @discardableResult
    public func subscribe(toEvents onEvent: @escaping (Event) -> Void) -> Disposable {
        let disposable = events.subscribe(onNext: onEvent)
        disposable.disposed(by: disposeBag)
        return disposable
    }

    public func asObservable() -> Observable<Event> {
        return Observable.create { [weak self] observer -> Disposable in
            self?.subscribe(toEvents: observer.onNext) ?? Disposables.create()
        }
    }

    // MARK: Setup

    private func setup() {
        refresh()
        // trying to refresh first in case view is already ready-to-go,
        // and subscribing for each `viewDidAppear` call to refresh all the settings (i.e. reconfigure constraints and gestures),
        // in case bottom panel was removed from the parent at some point and might have lost its constraints.
        let bottomPanelController: UIViewController? = bottomPanel
        bottomPanelController?.rx.viewDidAppear
            .subscribe(onNext: { [weak self] _ in
                self?.refresh()
            })
            .disposed(by: disposeBag)
    }

    /// Will recalculate sticky points and layout bottom panel in respect to its restoration point.
    public func refresh() {
        // we start setting up stuff once view is loaded and visible
        guard let bottomPanel = bottomPanel, bottomPanel.parent != nil, bottomPanel.isViewLoaded, bottomPanel.view.window != nil else {
            return
        }
        configScrollViewIfExists()
        removePanGestureRecognizers()
        setupPanGestureRecognizers()
        setupConstraintsAndAvailableAreaWithStickyPoints()

        let restorationStickyPoint: BottomPanelPoint.Relative
        switch bottomPanel.bottomPanelRestorationPoint {
        case .initialStickyPoint:
            restorationStickyPoint = bottomPanel.bottomPanelInitialStickyPoint.point(inArea: availableArea)
            // we also reset scroll-view offset if it's present, so that it appears without previous scrolling history
            bottomPanel.bottomPanelScrollView?.setContentOffset(.zero, animated: false)
        case .lastUsedStickyPoint:
            restorationStickyPoint = lastUsedStickyPoint ?? bottomPanel.bottomPanelInitialStickyPoint.point(inArea: availableArea)
        }
        setTopOffset(restorationStickyPoint, isGesture: false, animationDuration: .zero)
    }

    // MARK: Gestures

    private func configScrollViewIfExists() {
        guard let scrollView = bottomPanel?.bottomPanelScrollView, let superview = bottomPanel?.view.superview else {
            return
        }
        let topInset = scrollView.contentInset.top
        let bottomInset = superview.safeAreaInsets.bottom
        scrollView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
        scrollView.scrollIndicatorInsets = scrollView.contentInset
        scrollView.alwaysBounceVertical = true
    }

    private func setupPanGestureRecognizers() {
        addScrollViewPanGestureRecognizer()
        // if bottomPanel is, UITableViewController or any other controller with `view` being an instance of UIScrollView
        // we don't need to add custom pan gesture to it, because we've just subscribed to its native scroll gesture.
        guard bottomPanel?.view != bottomPanel?.bottomPanelScrollView else {
            return
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        bottomPanel?.view.addGestureRecognizer(pan)
        panGestureRecognizer = pan
    }

    private func removePanGestureRecognizers() {
        removeScrollViewPanGestureRecognizer()

        guard let pan = panGestureRecognizer, let view = bottomPanel?.view else {
            return
        }
        pan.removeTarget(self, action: #selector(handlePanGesture(_:)))

        if let gestures = view.gestureRecognizers, gestures.contains(pan) {
            view.removeGestureRecognizer(pan)
        }
    }

    private func addScrollViewPanGestureRecognizer() {
        bottomPanel?.bottomPanelScrollView?.panGestureRecognizer.addTarget(self, action: #selector(handleScrollViewGesture(_:)))
    }

    private func removeScrollViewPanGestureRecognizer() {
        bottomPanel?.bottomPanelScrollView?.panGestureRecognizer.removeTarget(self, action: #selector(handleScrollViewGesture(_:)))
    }

    @objc private func handleScrollViewGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard
            let bottomPanel = bottomPanel,
            let scrollView = bottomPanel.bottomPanelScrollView,
            let topConstraint = topConstraint,
            let firstStickyPoint = stickyPoints.first?.relative
        else {
            return
        }
        let isFullyExpanded = topConstraint.constant <= firstStickyPoint.value
        let yTranslation = gestureRecognizer.translation(in: scrollView).y
        let isScrollingDown = gestureRecognizer.velocity(in: scrollView).y > .zero
        let shouldDragViewDown = isScrollingDown && scrollView.contentOffset.y <= .zero
        let shouldDragViewUp = !isScrollingDown && !isFullyExpanded
        let shouldDragView = shouldDragViewDown || shouldDragViewUp

        if shouldDragView {
            scrollView.bounces = false
            scrollView.setContentOffset(.zero, animated: false)
        }
        switch gestureRecognizer.state {
        case .began:
            initialScrollViewContentOffset = scrollView.contentOffset
        case .changed:
            guard shouldDragView else {
                break
            }
            setTopOffset(availableArea.point(of: topConstraint.constant + yTranslation - initialScrollViewContentOffset.y), isGesture: true)
            gestureRecognizer.setTranslation(initialScrollViewContentOffset, in: scrollView)
        case .ended:
            scrollView.bounces = true

            guard shouldDragView || !stickyPoints.contains(where: { $0.relative.value == topConstraint.constant }) else {
                // Handle case when velocity is high enough to scroll the bottomPanel itself
                // Use decelerationRate and verticalVelocity and scrollView.contentOffset to find out where we stopped
                // Find velocity at contentOffset == 0
                // Apply this velocity to find estimated projected
                // Find nearestStickyPoint
                // Call goToNearestStickyPoint
                break
            }
            goToNearestStickyPoint(verticalVelocity: gestureRecognizer.velocity(in: bottomPanel.view).y)
            // redrawing scroll indicator to correspond to new scrollView size if it has changed (scrollView was dragged)
            scrollView.flashScrollIndicators()
        default:
            break
        }
    }

    @objc private func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let topConstraint = topConstraint, let view = bottomPanel?.view else {
            return
        }
        let yTranslation = gestureRecognizer.translation(in: view).y

        switch gestureRecognizer.state {
        case .changed:
            setTopOffset(availableArea.point(of: topConstraint.constant + yTranslation), isGesture: true, allowBounce: true)
            gestureRecognizer.setTranslation(.zero, in: view)
        case .ended:
            goToNearestStickyPoint(verticalVelocity: gestureRecognizer.velocity(in: view).y)
        default:
            break
        }
    }

    private func goToNearestStickyPoint(verticalVelocity: CGFloat) {
        guard let topConstraint = topConstraint else {
            return
        }

        // Velocity itself is too high, so in order to go to nearest point smoothly we lower velocity
        let slowDownVelocity = verticalVelocity / 5

        let decelerationRate = UIScrollView.DecelerationRate.normal.rawValue

        // The position where the point will be stopped after finger is released.
        // We have to compare this point with nearest sticky points
        let yProjectedPosition = topConstraint.constant + project(initialVelocity: slowDownVelocity, decelerationRate: decelerationRate)

        // Get nearest sticky point
        guard let nearestYPoint = nearestStickyPoint(to: yProjectedPosition) else {
            return
        }

        // Get relative velocity
        let relativeYVelocity = relativeVelocity(forVelocity: slowDownVelocity, from: topConstraint.constant, to: nearestYPoint.value)

        // Get vertical velocity
        let distanceToConver = abs(topConstraint.constant - nearestYPoint.value)
        let animationDuration = TimeInterval(abs(distanceToConver * 2 / relativeYVelocity)).inRange(min: 0.3, max: 0.55)

        setTopOffset(nearestYPoint, isGesture: true, animationDuration: animationDuration)
    }

    private func setTopOffset(_ point: BottomPanelPoint.Relative, isGesture: Bool, animationDuration: TimeInterval? = nil, allowBounce: Bool = false) {
        guard let bounceOffset = bottomPanel?.bottomPanelBounceOffset else {
            return
        }
        // Apply right value bounding for the provided bounce offset if needed
        let point: BottomPanelPoint.Relative = {
            guard let firstStickyPoint = stickyPoints.first?.relative, let lastStickyPoint = stickyPoints.last?.relative else {
                return point
            }
            let bounceOffset = allowBounce ? bounceOffset : .zero
            return point.inRange(min: firstStickyPoint - bounceOffset.top, max: lastStickyPoint + bounceOffset.bottom)
        }()
        topConstraint?.constant = point.value
        lastUsedStickyPoint = point

        if isGesture {
            let currentPoint = stickyPoints.first(where: { $0.relative == point })
                ?? BottomPanelPoint(relative: point, absolute: .init(relative: point))
            events.accept(.didDrag(currentPoint))
        }
        // `didMove` events should be called only if the user has ended the gesture.
        let shouldNotifyObserver = animationDuration != nil

        UIView.animate(
            withDuration: animationDuration ?? .zero,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: { [weak self] in
                self?.bottomPanel?.parent?.view.layoutIfNeeded()
            },
            completion: { [weak self] _ in
                // Recalculating point we've just arrived at, because this animation *allows user interaction*,
                // wich means it can be interrupted by dragging panel, say in a different direction,
                // and once we arrive here in completion block, topConstraint might be different.
                // It might lead to sending `didMove` event with stale point and cause errors on UI.
                guard shouldNotifyObserver,
                    let self = self,
                    let currentPointValue = self.topConstraint?.constant,
                    let currentPoint = self.stickyPoints.first(where: { $0.relative.value == currentPointValue })
                else { return }

                self.events.accept(.didMove(currentPoint, self.pointStatus(currentPoint)))
            }
        )
    }

    private func pointStatus(_ point: BottomPanelPoint) -> Event.Status {
        if self.stickyPoints.count == 1 {
            return .collapsed
        } else if point == self.stickyPoints.first {
            return .expanded
        } else if point == self.stickyPoints.last {
            return .collapsed
        } else {
            return .middle
        }
    }

    private func nearestStickyPoint(to yPosition: CGFloat) -> BottomPanelPoint.Relative? {
        return stickyPoints.map { value in (distance: abs(value.relative.value - yPosition), stickyPoint: value) }
            .min { $0.distance < $1.distance }?
            .stickyPoint
            .relative
    }

    private func relativeVelocity(forVelocity velocity: CGFloat, from currentValue: CGFloat, to targetValue: CGFloat) -> CGFloat {
        guard currentValue - targetValue != 0 else { return 0 }
        return velocity / (targetValue - currentValue)
    }

    /// Distance traveled after decelerating to zero velocity at a constant rate.
    private func project(initialVelocity: CGFloat, decelerationRate: CGFloat) -> CGFloat {
        return (initialVelocity / 1000) * decelerationRate / (1 - decelerationRate)
    }

    // MARK: Constraints

    private func setupConstraintsAndAvailableAreaWithStickyPoints() {
        guard let bottomPanel = bottomPanel, let view = bottomPanel.view, let superview = bottomPanel.view.superview else {
            return
        }
        // height constraint belongs to the view itself, and if there's one, lower its priority to not mess with top constraint.
        // p.s. iOS 12 doesn't allow changing priority of installed constrainе, so it needs to be created from scratch ¯\_(ツ)_/¯
        var heightConstraint = view.constraint(for: .height)
        if let height = heightConstraint, height.priority != .defaultLow, let firstItem = height.firstItem {
            heightConstraint = NSLayoutConstraint(
                item: firstItem,
                attribute: height.firstAttribute,
                relatedBy: height.relation,
                toItem: height.secondItem,
                attribute: height.secondAttribute,
                multiplier: height.multiplier,
                constant: height.constant
            )
            heightConstraint?.priority = .defaultLow
            view.removeConstraint(height)
            heightConstraint.map(view.addConstraint)
        }
        // if it's in parent, it means it can be bound to parent or to other view inside parent,
        // otherwise, we create our own constraints bound to parent's top, bottom, left and right.
        let leadingConstraint = view.constraint(for: .leading, in: superview)
            ?? view.leadingAnchor.constraint(equalTo: superview.leadingAnchor)
        let trailingConstraint = view.constraint(for: .trailing, in: superview)
            ?? view.trailingAnchor.constraint(equalTo: superview.trailingAnchor)
        let bottomConstraint = view.constraint(for: .bottom, in: superview)
            ?? view.bottomAnchor.constraint(equalTo: superview.bottomAnchor)

        if bottomPanel.bottomPanelIgnoreExistingTopConstraint {
            if let existingTopConstraint = view.constraint(for: .top, in: superview) {
                superview.removeConstraint(existingTopConstraint)
            }
            topConstraint = view.topAnchor.constraint(equalTo: superview.topAnchor)
        } else {
            // top constraint can be set to some other view above parent in hierarchy, but we don't consider this case here,
            // as it doesn't make much sense within home navigation stack (and please don't do that).
            topConstraint = view.constraint(for: .top, in: superview)
                ?? view.topAnchor.constraint(equalTo: superview.topAnchor)
            // if there was existing top constraint, make sure its relation is `equal`, otherwise it won't work ¯\_(ツ)_/¯
            // don't care about other constraints here as well
            if let top = topConstraint, top.relation != .equal, let firstItem = top.firstItem {
                topConstraint = NSLayoutConstraint(
                    item: firstItem,
                    attribute: top.firstAttribute,
                    relatedBy: .equal,
                    toItem: top.secondItem,
                    attribute: top.secondAttribute,
                    multiplier: top.multiplier,
                    constant: top.constant
                )
                superview.removeConstraint(top)
            }
        }
        NSLayoutConstraint.activate([topConstraint, leadingConstraint, trailingConstraint, bottomConstraint].compactMap { $0 })
        // should be calculated after the top constraint :)
        setupAvailableArea()
        setupStickyPoints()
    }

    private func setupAvailableArea() {
        guard let topConstraint = topConstraint, let view = bottomPanel?.view, let superview = bottomPanel?.view.superview else {
            return
        }
        let topInset = topConstraint.constant
        // as mentioned in `setupConstraintsAndAvailableArea`, we're not considering cases other than
        // having topConstraint bound to parent's top, safeAreaLayoutGuide top, or other view inside same parent.
        let (topSibling, topAttribute) = topConstraint.firstItem === view
            ? (topConstraint.secondItem, topConstraint.secondAttribute)
            : (topConstraint.firstItem, topConstraint.firstAttribute)

        if let topSiblingView = topSibling as? UIView {
            if topSiblingView == superview {
                availableArea = BottomPanelAvailableArea(absoluteY: .zero, topInset: topInset, height: superview.bounds.height)
            } else if topSiblingView.superview == superview {
                // well, bottom panel's top could have been bound to top's top constraint, so let's handle this as well.
                let originY = topAttribute == .bottom
                    ? topSiblingView.frame.origin.y + topSiblingView.frame.height
                    : topSiblingView.frame.origin.y
                availableArea = BottomPanelAvailableArea(absoluteY: originY, topInset: topInset, height: superview.bounds.height - originY)
            }
        } else if let layoutFrame = (topSibling as? UILayoutGuide)?.layoutFrame {
            availableArea = BottomPanelAvailableArea(absoluteY: layoutFrame.origin.y, topInset: topInset, height: layoutFrame.height)
        }
    }

    private func setupStickyPoints() {
        guard let bottomPanel = bottomPanel else { return }

        initialBottomPanelPoint = makeBottomPanelPoint(bottomPanel.bottomPanelInitialStickyPoint)
        stickyPoints = (bottomPanel.bottomPanelStickyPoints.compactMap(makeBottomPanelPoint) + [initialBottomPanelPoint].compacted)
            .sorted { $0.relative < $1.relative }
    }

    private var initialStickyPoint: BottomPanelPoint? {
        guard let bottomPanel = bottomPanel else {
            return nil
        }

        let relative = bottomPanel.bottomPanelInitialStickyPoint.point(inArea: availableArea)
        return BottomPanelPoint(
            sticky: bottomPanel.bottomPanelInitialStickyPoint,
            relative: relative,
            absolute: BottomPanelPoint.Absolute(relative: relative)
        )
    }

    private func makeBottomPanelPoint(_ bottomPanelInitialStickyPoint: BottomPanelStickyPoint) -> BottomPanelPoint? {
        guard bottomPanel != nil else {
            return nil
        }
        
        let relative = bottomPanelInitialStickyPoint.point(inArea: availableArea)
        return BottomPanelPoint(
            sticky: bottomPanelInitialStickyPoint,
            relative: relative,
            absolute: BottomPanelPoint.Absolute(relative: relative)
        )
    }
}

// MARK: - Utils

private extension UIView {
    func constraint(for attribute: NSLayoutConstraint.Attribute, in view: UIView? = nil) -> NSLayoutConstraint? {
        return (view ?? self).constraints.first { constraint in
            return (constraint.firstItem === self && constraint.firstAttribute == attribute)
                || (constraint.secondItem === self && constraint.secondAttribute == attribute)
        }
    }
}

private extension BottomPanelAvailableArea {
    func point(of value: CGFloat, keepInside: Bool = false) -> BottomPanelPoint.Relative {
        return BottomPanelPoint.Relative(value: keepInside ? value.inRange(min: topInset, max: height) : value, area: self)
    }
}

private extension BottomPanelStickyPoint {
    func point(inArea area: BottomPanelAvailableArea) -> BottomPanelPoint.Relative {
        let valueInArea: CGFloat = {
            switch self {
            case let .fromTop(value): return area.topInset + value.points(inArea: area)
            case let .fromBottom(value): return area.height - value.points(inArea: area)
            }
        }()
        return area.point(of: valueInArea, keepInside: true)
    }
}

private extension BottomPanelStickyPoint.Value {
    func points(inArea area: BottomPanelAvailableArea) -> CGFloat {
        switch self {
        case let .points(points): return points
        case let .percent(percent): return (area.height - area.topInset) * percent
        }
    }
}

extension BottomPanelPoint.Relative: Comparable {
    public static func < (lhs: BottomPanelPoint.Relative, rhs: BottomPanelPoint.Relative) -> Bool {
        return lhs.value < rhs.value
    }
}

private extension BottomPanelPoint.Relative {
    func map(_ transform: (CGFloat) -> CGFloat) -> BottomPanelPoint.Relative {
        var copy = self
        copy.value = transform(copy.value)
        return copy
    }

    static func + (lhs: CGFloat, rhs: BottomPanelPoint.Relative) -> BottomPanelPoint.Relative { return rhs.map { lhs + $0 } }
    static func + (lhs: BottomPanelPoint.Relative, rhs: CGFloat) -> BottomPanelPoint.Relative { return lhs.map { $0 + rhs } }
    static func - (lhs: CGFloat, rhs: BottomPanelPoint.Relative) -> BottomPanelPoint.Relative { return rhs.map { lhs - $0 } }
    static func - (lhs: BottomPanelPoint.Relative, rhs: CGFloat) -> BottomPanelPoint.Relative { return lhs.map { $0 - rhs } }
}

private extension BottomPanelPoint.Absolute {
    init(relative: BottomPanelPoint.Relative) {
        value = relative.area.absoluteY + relative.value
    }
}

extension BottomPanelPoint.Absolute: Comparable {
    public static func < (lhs: BottomPanelPoint.Absolute, rhs: BottomPanelPoint.Absolute) -> Bool {
        return lhs.value < rhs.value
    }
}

public extension BottomPanelHandler.Event {
    var didMove: (point: BottomPanelPoint, status: Status)? {
        guard case let .didMove(point, status) = self else { return nil }
        return (point, status)
    }

    var didDrag: BottomPanelPoint? {
        guard case let .didDrag(value) = self else { return nil }
        return value
    }

    var didRefreshStickyPoints: [BottomPanelPoint]? {
        guard case let .didRefreshStickyPoints(value) = self else { return nil }
        return value
    }
}
