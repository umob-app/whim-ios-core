import UIKit
import CoreLocation
import OrderedCollections

// MARK: - State

/// Represents map layer current state in a declarative fashion.
///
/// Used internally by the map view to render data correctly.
struct MapLayerState: Equatable {
    var configs: MapConfigs
    var visibleRectInset: MapLayerVisibleRectInset
    var sidebar: MapSidebar

    var centerPin: MapMarker.Content?
    var markers: Set<MapMarker>
    var overlays: OrderedSet<MapOverlay>
    var markerSelection: MapMarkerSelection?
    var plannedRoutes: OrderedSet<MapRoutePlan>

    var zoomLevel: Animatable<MapZoomLevel>
    var centerCoordinate: Animatable<CLLocationCoordinate2D>
    var heading: Animatable<CLLocationDirection>
    var isTrackingUser: Animatable<Bool>

    var clusterMarkerProvider: MapClusterMarkerProvider?
    var clusterConfigsProvider: MapClusterConfigsProvider?

    static let `default` = MapLayerState(
        configs: MapConfig.allWithoutMapDetails,
        visibleRectInset: .automatic(),
        sidebar: [.trackUser(highlightedContent: nil, normalContent: nil)],
        centerPin: nil,
        markers: [],
        overlays: [],
        markerSelection: nil,
        plannedRoutes: [],
        zoomLevel: Animatable(15, animated: true),
        // setting invalid default coordinate intentionally, so that map doesn't apply it and start at its default coordinate
        centerCoordinate: Animatable(defaultCenterCoordinate, animated: true),
        heading: Animatable(0, animated: true),
        isTrackingUser: Animatable(true, animated: true),
        clusterMarkerProvider: nil,
        clusterConfigsProvider: nil
    )

    static let defaultCenterCoordinate = kCLLocationCoordinate2DInvalid
}

// MARK: - Configs

public typealias MapConfigs = Set<MapConfig>

// sourcery: Random
public enum MapConfig: Int, Option, CaseIterable {
    case isScrollEnabled, isRotateEnabled, isZoomEnabled, showsCompass, showsUserLocation
    case isBuildingsEnabled, isTrafficEnabled, isPOIsEnabled

    public static let allWithoutMapDetails: MapConfigs = .all.subtracting(MapConfig.detailedMap)
    public static let detailedMap: MapConfigs = [.isBuildingsEnabled, .isTrafficEnabled, .isPOIsEnabled]
}

// MARK: - Marker Selection

// sourcery: Random
/// Represents marker selection progress.
public enum MapMarkerSelection: Equatable {
    case selecting(MapMarker)
    case selected(MapMarker)

    public var value: MapMarker {
        switch self {
        case let .selecting(marker): return marker
        case let .selected(marker): return marker
        }
    }

    public var isSelected: Bool {
        guard case .selected = self else { return false }
        return true
    }

    public var isSelecting: Bool {
        guard case .selecting = self else { return false }
        return true
    }
}

// MARK: - Zoom

// sourcery: Random
public struct MapCoordinateSpan: Equatable {
    public let latitudeDelta: CLLocationDegrees
    public let longitudeDelta: CLLocationDegrees

    public init(latitudeDelta: CLLocationDegrees, longitudeDelta: CLLocationDegrees) {
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }
}

// sourcery: Random
/// Zoom level which can be represented in different ways.
public enum MapZoomLevel: Equatable {
    // sourcery: Random
    public struct Padding: Equatable {
        public let factor: Double
        public let insets: UIEdgeInsets

        public init(factor: Double, insets: UIEdgeInsets) {
            self.factor = factor
            self.insets = insets
        }

        public static func factor(_ value: Double) -> Padding {
            .init(factor: value, insets: .zero)
        }

        public static func insets(_ value: UIEdgeInsets) -> Padding {
            .init(factor: 1, insets: value)
        }
    }

    /// Actual zoom. The bigger the value, the closer the map is.
    case zoom(Double)
    /// Allows zooming by specifying span in degrees. The bigger the value, the farther the map is.
    /// Additionally you can specify padding by applying factor multiplier first, and edge insets afterwards.
    case span(MapCoordinateSpan, Padding)

    /// Minimal possible zoom level (3).
    public static let min: MapZoomLevel = .zoom(minZoomLevel)
    /// Maximum possible zoom level (20).
    public static let max: MapZoomLevel = .zoom(maxZoomLevel)

    static let minZoomLevel: Double = 3
    static let maxZoomLevel: Double = 20
}

/// Allows expressing zoom with numeric literals.
extension MapZoomLevel: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    public init(floatLiteral value: Double) { self = .zoom(value) }
    public init(integerLiteral value: Double) { self = .zoom(value) }
}

public extension MapZoomLevel {
    var zoom: Double? {
        guard case let .zoom(value) = self else { return nil }
        return value
    }

    mutating func updateZoom(_ transform: (inout Double) -> Void) {
        guard var zoom = zoom else { return }
        transform(&zoom)
        self = .zoom(zoom)
    }

    func updatingZoom(_ transform: (Double) -> Double) -> MapZoomLevel {
        guard let zoom = zoom else { return self }
        return .zoom(transform(zoom))
    }

    /// Returns a zoom level incremented by one (if its value is `zoom`, otherwise - its current value).
    func zoomedIn() -> MapZoomLevel {
        updatingZoom { $0 + 1 }
    }

    /// Returns a zoom level decremented by one (if its value is `zoom`, otherwise - its current value).
    func zoomedOut() -> MapZoomLevel {
        updatingZoom { $0 - 1 }
    }
}

// MARK: - Visible Rect Inset

// sourcery: Random
/// Represents vertical inset with either custom layer value, or allowing to set this value automatically.
public struct MapLayerVisibleRectInset: Equatable {
    // sourcery: Random
    public enum Position: Equatable, CaseIterable {
        /// Absolute position means that map will not move its center or apply zoom level based on new visible rects.
        /// It will stay still and display exactly the same area as for the previous visible rect inset.
        case absolute
        /// Relative position means that map will adjust its center and apply same zoom level according to the new visible rect inset.
        case relative
        /// Coordinate-only means that map will keep layer's pre-set zoom and heading and will only transfer center coordinate.
        case coordinateOnly
    }

    // sourcery: Random
    public enum Value: Equatable {
        case custom(CGFloat)
        case automatic(CGFloat?)
    }

    public var top: Value
    public var bottom: Value
    /// Specify map behavior when visible rect inset changes. Default behavior is `relative`.
    public var position: Position

    public init(
        top: Value,
        bottom: Value,
        position: Position
    ) {
        self.top = top
        self.bottom = bottom
        self.position = position
    }
}

public extension MapLayerVisibleRectInset.Value {
    var value: CGFloat? {
        switch self {
        case let .custom(inset): return inset
        case let .automatic(inset): return inset
        }
    }

    var isAutomatic: Bool {
        guard case .automatic = self else { return false }
        return true
    }
}

public extension MapLayerVisibleRectInset {
    var isAnyAutomatic: Bool {
        return top.isAutomatic || bottom.isAutomatic
    }

    static func automatic(position: Position = .relative)  -> MapLayerVisibleRectInset {
        MapLayerVisibleRectInset(top: .automatic(.none), bottom: .automatic(.none), position: position)
    }

    static func custom(top: CGFloat, position: Position = .relative) -> MapLayerVisibleRectInset {
        return MapLayerVisibleRectInset(top: .custom(top), bottom: .automatic(.none), position: position)
    }

    static func custom(bottom: CGFloat, position: Position = .relative) -> MapLayerVisibleRectInset {
        return MapLayerVisibleRectInset(top: .automatic(.none), bottom: .custom(bottom), position: position)
    }

    static func custom(top: CGFloat, bottom: CGFloat, position: Position = .relative) -> MapLayerVisibleRectInset {
        return MapLayerVisibleRectInset(top: .custom(top), bottom: .custom(bottom), position: position)
    }
}

// MARK: - Sidebar

// TODO: think of extending sidebar to have a rule for when to fade, i.e. automatic, fixed point, or even a closure (point) -> alpha
public typealias MapSidebar = [MapSidebarItem]

public enum MapSidebarItem: Hashable {
    case trackUser(highlightedContent: Custom?, normalContent: Custom?)
    case reload(MapReloadSidebarItemView)
    case custom(Custom)
    case filter(highlightedContent: Custom?, normalContent: Custom?, isHighlighted: Bool)

    // sourcery: Random
    public struct Custom: Hashable {
        public typealias Id = String

        public let id: Id
        public var content: Content

        public init(id: Id, content: Content) {
            self.id = id
            self.content = content
        }
    }

    // sourcery: Random
    public enum Content: Hashable {
        case image(UIImage, tintColor: UIColor?)
        case view(UIView)

        public var image: UIImage? {
            guard case let .image(value, _) = self else { return nil }
            return value
        }

        public var view: UIView? {
            guard case let .view(value) = self else { return nil }
            return value
        }
    }
}

extension MapSidebarItem {
    public var isCustom: Bool {
        guard case .custom = self else { return false }
        return true
    }

    public var isReload: Bool {
        guard case .reload = self else { return false }
        return true
    }

    public var isTrackUser: Bool {
        guard case .trackUser = self else { return false }
        return true
    }

    public var isFilter: Bool {
        guard case .filter = self else { return false }
        return true
    }

    public var custom: Custom? {
        guard case let .custom(item) = self else { return nil }
        return item
    }

    public var reload: MapReloadSidebarItemView? {
        guard case let .reload(item) = self else { return nil }
        return item
    }

    public var filter: Bool? {
        guard case let .filter(_, _, isFiltered) = self else { return nil }
        return isFiltered
    }

    public func content(isHighlighted: Bool = false) -> Content {
        switch self {
        case let .trackUser(highlightedContent, normalContent):
            isHighlighted
                ? highlightedContent?.content ?? .image(UIImage(systemName: "location.fill")!, tintColor: nil)
                : normalContent?.content ?? .image(UIImage(systemName: "location")!, tintColor: nil)
        case let .reload(reload):
            .view(reload)
        case let .custom(custom):
            custom.content
        case let .filter(highlightedContent, normalContent, isHighlighted):
            isHighlighted
                ? highlightedContent?.content ?? .image(UIImage(systemName: "gearshape")!, tintColor: nil)
                : normalContent?.content ?? .image(UIImage(systemName: "gearshape.fill")!, tintColor: nil)
        }
    }

    public static func reloadNormal(highlightColor: UIColor, normalTintColor: UIColor) -> MapSidebarItem {
        .reload(MapReloadSidebarItemView(style: .normal, highlightColor: highlightColor, normalTintColor: normalTintColor))
    }

    public static func custom(id: String, image: UIImage, tintColor: UIColor? = nil) -> MapSidebarItem {
        .custom(.init(id: id, content: .image(image, tintColor: tintColor)))
    }

    public static func custom(id: String, view: UIView) -> MapSidebarItem {
        .custom(.init(id: id, content: .view(view)))
    }

    public static var trackUser: MapSidebarItem {
        .trackUser(highlightedContent: nil, normalContent: nil)
    }

    public static func filter(isHighlighted: Bool) -> MapSidebarItem {
        .filter(highlightedContent: nil, normalContent: nil, isHighlighted: isHighlighted)
    }
}

// MARK: - Route

// sourcery: Random
public struct MapRoutePlan: Hashable {
    // TODO: think of making it extendable and configurable by the user
    // sourcery: Random
    public enum TransportType: Int, Option, CaseIterable {
        case driving, walking, publicTransport, any
    }

    // sourcery: Random
    public enum RenderStrategy: Hashable {
        case always, zoomLessThan(Double), zoomGreaterThan(Double)
    }

    // sourcery: Random
    public enum Status: Equatable {
        case idle
        case calculating
        case finished(Result<Response, NSError>)
    }

    // sourcery: Random
    public struct Response: Equatable {
        public let coordinates: [CLLocationCoordinate2D]
        public let steps: [Step]

        public init(coordinates: [CLLocationCoordinate2D], steps: [Step]) {
            self.coordinates = coordinates
            self.steps = steps
        }
    }

    // sourcery: Random
    public struct Step: Equatable {
        public let coordinates: [CLLocationCoordinate2D]
        public let transportType: Set<TransportType>

        public init(coordinates: [CLLocationCoordinate2D], transportType: Set<TransportType>) {
            self.coordinates = coordinates
            self.transportType = transportType
        }
    }

    public let source: CLLocationCoordinate2D
    public let destination: CLLocationCoordinate2D
    public let transportType: Set<TransportType>
    public let rendering: RenderStrategy
    public let polylinesProvider: FunctionObject<Response, OrderedSet<MapPolyline>>

    public internal(set) var status: Status
    public internal(set) var polylines: OrderedSet<MapPolyline>?

    public init(
        source: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        transportType: Set<TransportType> = [.walking],
        renderWhen: RenderStrategy = .always,
        polylinesProvider: FunctionObject<Response, OrderedSet<MapPolyline>>
    ) {
        self.source = source
        self.destination = destination
        self.transportType = transportType
        self.rendering = renderWhen
        self.polylinesProvider = polylinesProvider
        self.status = .idle
        self.polylines = nil
    }

    public static func == (lhs: MapRoutePlan, rhs: MapRoutePlan) -> Bool {
        // intentionally skipping status and polylines here to have equality only by coordinates and transport type
        return lhs.source == rhs.source
            && lhs.destination == rhs.destination
            && lhs.transportType == rhs.transportType
            && lhs.rendering == rhs.rendering
    }

    public func hash(into hasher: inout Hasher) {
        // intentionally skipping status and polylines here to have hashing + equality only by coordinates and transport type
        hasher.combine(source)
        hasher.combine(destination)
        hasher.combine(transportType)
        hasher.combine(rendering)
    }
}

public extension MapRoutePlan.Status {
    var isIdle: Bool {
        return self == .idle
    }
    var isCalculating: Bool {
        return self == .calculating
    }
    var isFinished: Bool {
        guard case .finished = self else { return false }
        return true
    }
}

public extension MapRoutePlan.RenderStrategy {
    func shouldDisplayPolylines(at zoomLevel: Double) -> Bool {
        switch self {
        case .always:
            return true
        case let .zoomGreaterThan(bound):
            return zoomLevel > bound
        case let .zoomLessThan(bound):
            return zoomLevel < bound
        }
    }
}
