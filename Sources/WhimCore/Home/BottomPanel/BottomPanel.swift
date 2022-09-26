import UIKit

// MARK: - Sticky Point

/// Represents sticky point in relative values.
///
/// You can specify value that will be calculated either from top or bottom in the botom panel coordinate system.
///
/// i.e having rect size of 900 points, and sticky points with 100 pt from top and 200 pt from bottom,
/// will automatically turn them into 100 and 700 pt in absolute values respectively.
/// ```
///    0
///     ┌──────────┐
///     │          │
/// 100 ├──────────┤ -> 100
///     │ fromTop  │
///     │          │
/// 200 ├──────────┤ -> 700
///     │fromBottom│
///     └──────────┘
///  900
/// ```
public enum BottomPanelStickyPoint: Hashable {
    /// Value relative to the top of the area.
    case fromTop(Value)
    /// Value relative to the bottom of the area.
    case fromBottom(Value)

    public enum Value: Hashable {
        /// Value in screen points.
        case points(CGFloat)
        /// Value in percent from 0 to 1.
        case percent(CGFloat)
    }
}

public extension BottomPanelStickyPoint {
    func value(inRect rect: CGRect) -> CGFloat {
        let valueInRect: CGFloat = {
            switch self {
            case let .fromTop(value): return value.points(inRect: rect)
            case let .fromBottom(value): return rect.height - value.points(inRect: rect)
            }
        }()
        return valueInRect.inRange(min: rect.origin.y, max: rect.height)
    }
}

public extension BottomPanelStickyPoint.Value {
    func points(inRect rect: CGRect) -> CGFloat {
        switch self {
        case let .points(points): return points
        case let .percent(percent): return rect.height * percent
        }
    }
}

/// Aggregates requested sticky point with its calculated values for different areas.
///
/// i.e having superview (bottom panel container) size of 900 points,
/// with top bar of 120 points height, and an existing constraint between top bar and bottom panel with constant ≥ 25,
/// and sticky points with 100 pt from top and 200 pt from bottom:
/// ```
///      0
///      ┌──────────┐
///  120 │ top bar  │
///  ≥25 ╞══════════╡
///      │          │
/// ↓100 ├──────────┤ -> absolute: 120+25+100=245, relative: 25+100=125
///      │  panel   │
///      │ expanded │
/// ↑200 ├──────────┤ -> absolute: 900-200=700, relative: 900-120-200=580
///      │collapsed │
///      └──────────┘
///      900
/// ```
public struct BottomPanelPoint: Hashable {
    /// Associated sticky point.
    /// It can be `nil` in case it's just an arbitrary point in area.
    public let sticky: BottomPanelStickyPoint?
    public let absolute: Absolute
    public let relative: Relative

    public init(sticky: BottomPanelStickyPoint? = nil, relative: Relative, absolute: Absolute) {
        self.sticky = sticky
        self.absolute = absolute
        self.relative = relative
    }
}

extension BottomPanelPoint {
    /// Point relative to available area (i.e. excluding top bar and respecting existing top constraint).
    /// Relative values are mostly used inside the bottom panel for the internal calculations.
    public struct Relative: Hashable {
        public internal(set) var value: CGFloat
        internal let area: BottomPanelAvailableArea
    }

    /// Point with absolute value in parent rect.
    /// Absolute values are mostly used outside of the bottom panel.
    public struct Absolute: Hashable {
        public let value: CGFloat
    }
}

/// Represents area that can be used by bottom panel.
/// Relies on correct top constraint, so it should be calculated after it, and has `zero` value before top constraint is setup.
///
/// i.e. if there's top bar and bottom panel on the screen, it means that bottom panel can be used until top bar's bottom point.
internal struct BottomPanelAvailableArea: Hashable {
    /// Absolute origin y value within parent (needed mostly for debugging).
    let absoluteY: CGFloat
    /// Respects initial top constraint inset (if there is existing top constraint with some constant value).
    let topInset: CGFloat
    /// Height of available area without inset (total available height from top constraint, ignoring its constant, to bottom).
    let height: CGFloat

    static let zero = BottomPanelAvailableArea(absoluteY: .zero, topInset: .zero, height: .zero)
}

// MARK: - Bounce Offset

/// Bounce offset from top and bottom sides.
///
/// Use static helpers to quickly create needed config.
public struct BottomPanelBounceOffset: Equatable {
    public let top: CGFloat
    public let bottom: CGFloat

    public init(top: CGFloat, bottom: CGFloat) {
        self.top = top
        self.bottom = bottom
    }

    public static var zero: BottomPanelBounceOffset { return .both(.zero) }
    public static func top(_ offset: CGFloat) -> BottomPanelBounceOffset { return .init(top: offset, bottom: .zero) }
    public static func bottom(_ offset: CGFloat) -> BottomPanelBounceOffset { return .init(top: .zero, bottom: offset) }
    public static func both(_ offset: CGFloat) -> BottomPanelBounceOffset { return .init(top: offset, bottom: offset) }
}

/// Represents a point to restore from when bottom panel is refreshed (i.e. on next `viewDidAppear`).
public enum BottomPanelRestorationPoint {
    /// Will restore to initial sticky point.
    case initialStickyPoint
    /// Will keep its position on the last sticky point it was opened.
    case lastUsedStickyPoint
}

// MARK: - Bottom Panel

/// Bottom Panel can only be implemented by UIViewController subclass.
/// Design inspired by BottomSheet component from existing V2 home flow.
/// It allows turning view controller into bottom panel, that can be dragged and aligned according to provided sticky points.
/// It can be used with simpe view controller as well as with view controller that is backed by the scroll view
/// in order to move with its content.
///
/// Its core logic is backed by autolayout mechanics
/// and it fits well to our Home Scene Navigation, as it highly relies on autolayout as well.
/// Bottom panel will try to figure out existing constraints and if it doesn't find needed, it will create them.
/// It attaches pan gesture recongnizer to the root view and modifies top constraint accordingly.
///
/// When using it within Home Scene, which might consist of top and bottom controllers,
/// bottom panel will automatically configure itself to stick to the bottom of the top bar, so that they don't overlap.
/// However this behavior can be configured as well with `bottomPanelIgnoreExistingTopConstraint` property.
///
/// Most of the properties are provided with default values, so minimum required setup would be
/// to provide `bottomPanelHandler` and become its `bottomPanel`:
/// ```
/// final class MenuViewController: UIViewController, BottomPanel {
///     private(set) lazy var bottomPanelHandler = { BottomPanelHandler(bottomPanel: self) }()
/// }
/// ```
public protocol BottomPanel: UIViewController {
    /// The desired intial sticky point.
    var bottomPanelInitialStickyPoint: BottomPanelStickyPoint { get }

    /// Set of unique sticky points.
    /// At the end of the gestures the bottom panel will scroll to the nearest point in the list.
    /// It doesn't matter whether you include initial sticky point here or not.
    var bottomPanelStickyPoints: Set<BottomPanelStickyPoint> { get }

    /// A CGFloat value that determines how much the bottom panel's view can bounce outside of its size.
    var bottomPanelBounceOffset: BottomPanelBounceOffset { get }

    /// When set to `true`, bottom panel will ignore existing top constraint and create its own one bound to the parent's top.
    /// Default value is `false`.
    var bottomPanelIgnoreExistingTopConstraint: Bool { get }

    /// Optional scroll view which, if provided, will be used to drag bottom panel along with its content.
    var bottomPanelScrollView: UIScrollView? { get }

    /// Provide a handler that performs all of the logic behind the scenes :)
    var bottomPanelHandler: BottomPanelHandler { get }

    /// Choose how to restore bottom panel after screen is shown after being hidden (i.e. in navigation stack).
    /// Defaults to initial sticky point.
    var bottomPanelRestorationPoint: BottomPanelRestorationPoint { get }
}

// MARK: - Default Configs

public extension BottomPanel {
    var bottomPanelInitialStickyPoint: BottomPanelStickyPoint {
        return .fromBottom(.points(400))
    }
    var bottomPanelStickyPoints: Set<BottomPanelStickyPoint> {
        return [.fromTop(.points(100)), .fromBottom(.points(100)), bottomPanelInitialStickyPoint]
    }
    var bottomPanelBounceOffset: BottomPanelBounceOffset {
        return .top(25)
    }
    var bottomPanelIgnoreExistingTopConstraint: Bool {
        return false
    }
    var bottomPanelScrollView: UIScrollView? {
        return nil
    }
    var bottomPanelRestorationPoint: BottomPanelRestorationPoint {
        return .initialStickyPoint
    }
}
