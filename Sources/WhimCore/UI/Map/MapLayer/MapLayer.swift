import Foundation
import CoreLocation
import RxSwift
import RxRelay
import OrderedCollections

// TODO: implement a way to plan route using original MKMapView API (like `setPolylineRoute` extension we use).

/// Represents data that is rendered on the map and ways to interact with it.
/// It receives events from the map view, applies them to its state, and notifies map view of state updates under the hood.
///
/// The idea is to allow different clients to activate different layers to render their data on a shared map.
/// Together with layer manager, it allows deciding who's in charge of the map atm,
/// without ways to mess it up if someone else gains control, which would happen if you'd share an instance to a single map view.
///
/// You can change layer's properties and call its methods while inactive.
/// The latest state will be applied as soon as layer becomes active.
///
/// One of the tasks was to have an abstract interface so it'd be easier to switch map provider later (apple, google, or else),
/// so instead of MapKit interfaces, you will see custom API here.
///
/// However it wasn't intended to have fully abstract interface, as it'd take enormous efforts to come up with one.
/// So its task is to solve current app's problems,
/// thus it includes only those properties and functions that are being used by existing features, with minimal tradeoffs.
///
/// - Important: `MapLayer` should be used only on Main thread.
public final class MapLayer<Context> {
    internal typealias StateObserver = (MapLayerState) -> Void

    /// Unique layer identifier.
    public let token: MapLayerToken

    /// Context in which this layer operates.
    /// Can be used to identify the layer when need to decide which properties to transfer from previous layer while switching.
    public let context: Context?

    /// If layer is active, it means it's rendered on the map and user interacts with it through the map view.
    public private(set) var isActive: Bool = false

    /// Events coming from the map view or notifying of layer changes.
    public var events: Observable<MapLayerEvent> { eventsRelay.asObservable() }
    private let eventsRelay = PublishRelay<MapLayerEvent>()

    internal private(set) var state: MapLayerState
    private let stateObserver: StateObserver

    /// Can be only created internally by its manager.
    internal init(token: MapLayerToken, context: Context?, stateObserver: @escaping StateObserver) {
        self.token = token
        self.stateObserver = stateObserver
        self.state = .default
        self.context = context
    }

    /// Basic map view configs that we're using in the app.
    public var configs: MapConfigs {
        get { state.configs }
        set { updateState(notifyingObserver: true) { $0.configs = newValue } }
    }

    /// Vertical content inset that specifies area where map will be centered.
    ///
    /// Imagine our map screen is of `300x500` size with center in `150,250`.
    /// Once we set new vertical inset `(top: 20, bottom: 220)`,
    /// visible rect becomes `0,20x300,280` of `300x260` size with center in `150x((260/2)+20) = 150x150` relative to the whole map.
    /// ```
    /// 0,0          0,0      ↓
    ///  +–––––+      +=====+ 20
    ///  |     |      |  +  |
    ///  |  +  |  =>  +–––––+ 220
    ///  |     |      |     | ↑
    ///  +–––––+      +–––––+
    ///     300,500      300,500
    /// ```
    public var visibleRectInset: MapLayerVisibleRectInset {
        get { state.visibleRectInset }
        set { updateState(notifyingObserver: true) { $0.visibleRectInset = newValue } }
    }

    /// Sidebar menu with vertically stacked controls.
    /// Ordered from bottom to top - bottom first, top - last.
    public var sidebar: MapSidebar {
        get { state.sidebar }
        set { updateState(notifyingObserver: true) { $0.sidebar = newValue } }
    }

    public var centerPin: MapMarker.Content? {
        get { state.centerPin }
        set { updateState(notifyingObserver: true) { $0.centerPin = newValue } }
    }

    /// Set of markers to render on the map. We don't care about their order, but we do care about keeping them unique.
    ///
    /// When setting new markers and selected marker isn't among them, it'll be set to `nil`.
    public var markers: Set<MapMarker> {
        get { state.markers }
        set {
            updateState(notifyingObserver: true) { state in
                state.markers = newValue
                if let selectedMarker = state.markerSelection, !state.markers.contains(selectedMarker.value) {
                    state.markerSelection = nil
                }
            }
        }
    }

    /// Returns read-only marker selection progress.
    /// Use `selectMarker` to select a new marker.
    public var selectedMarker: MapMarkerSelection? {
        state.markerSelection
    }

    /// Set of overlays to render on the map. Order is respected to represent their z-index.
    public var overlays: OrderedSet<MapOverlay> {
        get { state.overlays }
        set { updateState(notifyingObserver: true) { $0.overlays = newValue } }
    }

    /// Planned routes by given source + destination coordinates and a transport type.
    ///
    /// Initial status is `idle`, then `calculating` once calculation has started, and `finished` containig result with response.
    ///
    /// If layer becomes inactive while status is `calculating`, this status is kept until layer is active again,
    /// and calculation will start again then.
    ///
    /// When given few routes at a time, their statuses will update once all of them are calculated,
    /// and their polylines will be created based on their responses and given `polylinesProvider`s.
    ///
    /// When setting new routes, and some of them are already calculated within existing routes, they WILL NOT be reset,
    /// but instead they will be reused. This is done to reduce expensive calculations.
    /// i.e. Apple has pretty strict throttling rules and it will return errors once exceeded,
    /// and Google directions is a paid feature at all.
    /// Ideally each layer client should make sure to cache such routes when possible if there're many of them and they're static.
    ///
    /// Resulting polylines are kept here and do not appear in `overlays` to not mix them together.
    ///
    /// Route is calculated asynchronously by the map provider.
    public var plannedRoutes: OrderedSet<MapRoutePlan> {
        get { state.plannedRoutes }
        set { updateState(notifyingObserver: true) { state in
            state.plannedRoutes = newValue.reduce(into: []) { acc, item in
                if let idx = state.plannedRoutes.firstIndex(of: item) {
                    acc.append(state.plannedRoutes[idx])
                } else {
                    acc.append(item)
                }
            }
        } }
    }

    /// Zoom level, identical to google maps zoom layer.
    /// Apple map kit uses region and span to represent visible area on the map.
    ///
    /// You can find zoom level in `span` option here, only if you set such zoom level while layer being inactive.
    /// When layer is active, zoom level will be immediately changed to `zoom` option even if setting it with `span`.
    ///
    /// If you want to animate the change in zoom level, use the `setZoomLevel(_:animated:)` method instead.
    public var zoomLevel: MapZoomLevel {
        get { state.zoomLevel.value }
        set { setZoomLevel(newValue, animated: false) }
    }

    /// Center coordinate of the map.
    ///
    /// If you want to animate the change in center coordinate, use the `setCenter(_:zoomLevel:animated:)` method instead.
    public var centerCoordinate: CLLocationCoordinate2D {
        get { state.centerCoordinate.value }
        set { setCenter(newValue, zoomLevel: nil, animated: false) }
    }

    /// Represents camera direction.
    ///
    /// If you want to animate the change in heading, use the `setHeading(_:animated:)` method instead.
    public var heading: CLLocationDirection {
        get { state.heading.value }
        set { setHeading(newValue, animated: false) }
    }

    /// States whether map follows user as their location changes.
    /// When this flag is `true`, map ignores current `centerCoordinate` and updates it with actual user location.
    ///
    /// If you want to animate the change in user tracking, use the `setTrackingUser(_:animated:)` method instead.
    public var isTrackingUser: Bool {
        get { state.isTrackingUser.value }
        set { setTrackingUser(newValue, animated: false) }
    }

    /// Generates cluster marker with rendering data for a given map cluster.
    ///
    /// Needed only if there're markers with non-nil clustering identifier.
    /// If nil, map will use its default cluster marker presentation.
    public var clusterMarkerProvider: MapClusterMarkerProvider? {
        get { state.clusterMarkerProvider }
        set { updateState(notifyingObserver: true) { $0.clusterMarkerProvider = newValue } }
    }

    /// Providers cluster rendering configs for a given map cluster identifier.
    ///
    /// Needed only if there're markers with non-nil clustering identifier.
    /// If nil, map will use its default cluster rendering configs.
    public var clusterConfigsProvider: MapClusterConfigsProvider? {
        get { state.clusterConfigsProvider }
        set { updateState(notifyingObserver: true) { $0.clusterConfigsProvider = newValue } }
    }

    /// Change center coordinate and zoom level with optional animation.
    ///
    /// If layer is inactive, it will keep chosen `zoomLevel` option, but as soon as it becomes active, `zoomLevel` will be `zoom`.
    public func setCenter(_ coordinate: CLLocationCoordinate2D, zoomLevel: MapZoomLevel? = nil, animated: Bool = false) {
        updateState(notifyingObserver: true) { state in
            // if we manually change center coordinate, we no longer intend to track the user
            if state.centerCoordinate.value != coordinate {
                state.isTrackingUser.value = false
            }
            state.centerCoordinate.setValue(coordinate, animated: animated)
            if let zoom = zoomLevel {
                state.zoomLevel.setValue(zoom, animated: animated)
            }
        }
    }

    /// Change zoom level with optional animation.
    ///
    /// If layer is inactive, it will keep chosen `zoomLevel` option, but as soon as it becomes active, `zoomLevel` will be `zoom`.
    public func setZoomLevel(_ zoomLevel: MapZoomLevel, animated: Bool = false) {
        updateState(notifyingObserver: true) { state in
            state.zoomLevel.setValue(zoomLevel, animated: animated)
        }
    }

    /// Change camera direction with optional animation.
    public func setHeading(_ heading: CLLocationDirection, animated: Bool = false) {
        updateState(notifyingObserver: true) { state in
            state.heading.setValue(heading, animated: animated)
        }
    }

    /// Change if map should follow user location with optional animation.
    /// When set to `true`, map ignores current `centerCoordinate` and updates it with actual user location.
    public func setTrackingUser(_ isTrackingUser: Bool, animated: Bool = false) {
        updateState(notifyingObserver: true) { state in
            state.isTrackingUser.setValue(isTrackingUser, animated: animated)
        }
    }

    /// We can't select a marker by just setting its `isSelected` property (at least with Apple Maps).
    /// Instead, we should select it using map view API (map layer in our case).
    ///
    /// - In case you select a marker while layer is active, it will quickly switch from `selecting` to `selected` state,
    /// and notify with the corresponding event.
    /// - In case you select a marker while layer is not active, it will be in a `selecting` state until layer is active again.
    /// - If such marker doesn't belong to this layer, or is already selecting/selected, this operation will be ignored.
    public func selectMarker(_ marker: MapMarker) {
        guard markers.contains(marker), state.markerSelection?.value != marker else {
            return
        }
        updateState(notifyingObserver: true) { state in
            state.markerSelection = .selecting(marker)
        }
    }

    public func deselectAnyMarker() {
        guard state.markerSelection != nil else {
            return
        }
        updateState(notifyingObserver: true) { state in
            state.markerSelection = nil
        }
    }

    private func updateState(notifyingObserver shouldNotify: Bool, transform: (inout MapLayerState) -> Void) {
        transform(&state)
        if shouldNotify {
            stateObserver(state)
        }
    }

    /// Internal method, should only be used by the manager.
    internal func handle(event: MapEvent) {
        switch event {
        case let .changingPosition(.ended, center, zoom, heading, _), let .changingPosition(.inProgress, center, zoom, heading, _):
            // `starting` status will bring old values where it begins changing position,
            // thus updating state only on `inProgress` and `ended` events
            updateState(notifyingObserver: false) { state in
                state.centerCoordinate.value = center
                state.zoomLevel.value = .zoom(zoom)
                state.heading.value = heading
            }
        case let .didUpdateVisibleRectInset(inset):
            updateState(notifyingObserver: false) { state in
                state.visibleRectInset = inset
            }
        case let .didUpdateUserTracking(isTrackingUser):
            updateState(notifyingObserver: false) { state in
                state.isTrackingUser.value = isTrackingUser
            }
        case .didTapSidebarItem(.trackUser):
            updateState(notifyingObserver: true) { state in
                state.isTrackingUser = Animatable(true, animated: true)
            }
        case let .didSelectMarker(marker, isSelected):
            updateState(notifyingObserver: false) { state in
                if isSelected {
                    state.markerSelection = .selected(marker)
                } else if state.markerSelection?.value == marker {
                    state.markerSelection = nil
                }
            }
        case let .didStartCalculatingRoutes(plannedRoutes):
            updateState(notifyingObserver: true) { state in
                for var plannedRoute in plannedRoutes where state.plannedRoutes.contains(plannedRoute) {
                    plannedRoute.status = .calculating
                    state.plannedRoutes.updateOrAppend(plannedRoute)
                }
            }
        case let .didFinishCalculatingRoutes(plannedRoutesResult):
            updateState(notifyingObserver: true) { state in
                for (var plannedRoute, result) in plannedRoutesResult where state.plannedRoutes.contains(plannedRoute) {
                    plannedRoute.status = .finished(result)
                    if case let .success(response) = result {
                        let polylines = plannedRoute.polylinesProvider(response)
                        plannedRoute.polylines = polylines
                    }
                    state.plannedRoutes.updateOrAppend(plannedRoute)
                }
            }
        case .changingPosition, .didTapSidebarItem, .didTap, .didTapInsideOverlay, .didTapOnCluster:
            break
        }
        eventsRelay.accept(.map(event))
    }

    /// Internal method, should only be used by the manager.
    internal func didBecomeActive(_ isActive: Bool) {
        self.isActive = isActive
        eventsRelay.accept(.didBecomeActive(isActive))
    }
}

// MARK: - Extensions

public extension MapLayer {
    static var defaultPadding: MapZoomLevel.Padding { .init(factor: 1.5, insets: .zero) }

    func zoomToFitCoordinates(_ coordinates: [CLLocationCoordinate2D], padding: MapZoomLevel.Padding = defaultPadding, animated: Bool = false) {
        guard !coordinates.isEmpty else { return }

        let topLeftMax = CLLocationCoordinate2D(latitude: -90, longitude: 180)
        let bottomRightMax = CLLocationCoordinate2D(latitude: 90, longitude: -180)

        let region = coordinates.reduce(into: (topLeft: topLeftMax, bottomRight: bottomRightMax)) { acc, coord in
            acc.topLeft.longitude = fmin(acc.topLeft.longitude, coord.longitude)
            acc.topLeft.latitude = fmax(acc.topLeft.latitude, coord.latitude)

            acc.bottomRight.longitude = fmax(acc.bottomRight.longitude, coord.longitude)
            acc.bottomRight.latitude = fmin(acc.bottomRight.latitude, coord.latitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: region.topLeft.latitude - (region.topLeft.latitude - region.bottomRight.latitude) / 2,
            longitude: region.topLeft.longitude + (region.bottomRight.longitude - region.topLeft.longitude) / 2
        )
        let span = MapCoordinateSpan(
            latitudeDelta: fabs(region.topLeft.latitude - region.bottomRight.latitude),
            longitudeDelta: fabs(region.bottomRight.longitude - region.topLeft.longitude)
        )
        setCenter(center, zoomLevel: .span(span, padding), animated: animated)
    }

    /// Will be ignored if current center coordinate is invalid.
    func zoomToFitRadius(_ radius: CLLocationDistance, padding: MapZoomLevel.Padding = defaultPadding, animated: Bool = false) {
        guard CLLocationCoordinate2DIsValid(state.centerCoordinate.value) else {
            return
        }
        let region = CircularRegion(center: state.centerCoordinate.value, radius: radius)
        let coordinateSpan = MapCoordinateSpan(latitudeDelta: region.span.latitudeDelta, longitudeDelta: region.span.longitudeDelta)
        setZoomLevel(.span(coordinateSpan, padding), animated: animated)
    }

    func updateZoom(_ transform: (inout Double) -> Void, animated: Bool = false) {
        updateState(notifyingObserver: true) { state in
            state.zoomLevel.updateValue({ $0.updateZoom(transform) }, animated: animated)
        }
    }
}
