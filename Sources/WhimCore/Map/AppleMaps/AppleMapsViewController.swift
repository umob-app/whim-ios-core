import UIKit
import MapKit
import RxSwift
import RxCocoa
import RxRelay
import OrderedCollections

// MARK: - View Controller

/// Whoever embeds the map to itself (a WhimSceneContainerViewController or UIViewController), should implement this protocol to specify the interactive bounds of the map.
public protocol MapViewControllerDynamicLayoutGuide: AnyObject {
    /// Affects how the map treats its layout margins (including rendering of the legal label and logo), and updates layer's ``MapLayer/visibleRectInset`` if needed.
    var mapVerticalInset: ObservableProperty<VerticalInsets> { get }
    /// Affects where (from the bottom) a map sidebar should be rendered.
    /// If you are using a ``BottomPanel``, then you should subscribe to its updates os that the sidebar could move along with the bottom panel.
    var mapSidebarBottomInset: ObservableProperty<CGFloat> { get }
}

// TODO: MAP Possible Optimization: Think of caching clustering managers for layers that haven't been removed from the manager yet.
//           If layer hasn't been removed, it means there's a chance it might be back again,
//           and in order to not create whole quadtree, manager, algorithm and renderer again, we might just keep it cached somehow.

public final class AppleMapsViewController<Context>: UIViewController, MapLayerManagerDelegate, MKMapViewDelegate, UIGestureRecognizerDelegate {
    private enum UI {
        static var sidebarWidth: CGFloat { 40 }
        static var sidebarRightInset: CGFloat { 16 }
        // 30 will provide the same spacing for sidebar's bottom to the legal label's top coordinate,
        // as it is from legal label's bottom to the safe area bottom inset, i.e. `V:|sidebar-legal-safeArea|`.
        static var sidebarBottomInset: CGFloat { 30 }
        // 10 is original legal label and apple logo insets (revealed in Debug mode),
        // and we want them to be aligned equally with sidebar and other UI components.
        static var logoAndLegalHorizontalInset: CGFloat { sidebarRightInset - 10 }
    }

    /// We don't need other properties from `MapLayerState`, as they become irrelevant pretty quickly,
    /// And `MKMapView` becomes primary source of truth here, as user interacts with it.
    /// However, configs, insets, markers and overlays stay the same.
    /// And token helps to distinguish which layer controls the map atm.
    private struct Layer {
        let token: MapLayerToken?
        /// Due to the fact that switching to a new scene takes two steps and some time (switch map layer + switch actual screen),
        /// we need to keep track of initially requested position for some time until it can be used for once, then it is nullified.
        /// - Note: See `setDefaultMapVerticalInset` for actual usage.
        var initialPosition: MapLayerVisibleRectInset.Position?
        var configs: MapConfigs
        var visibleRectInset: MapLayerVisibleRectInset
        var sidebar: [MapSidebarItem]
        var centerPin: MapMarker.Content?
        var markers: Set<MapMarker>
        var overlays: OrderedSet<MapOverlay>
        var markerSelection: MapMarkerSelection?
        var plannedRoutesRequests: OrderedSet<PlannedRouteRequest>

        var clusterMarkerProvider: MapClusterMarkerProvider?
        var clusterConfigsProvider: MapClusterConfigsProvider?
        var clusterManagers: [String: MapClusterManager]

        struct PlannedRouteRequest: Hashable {
            var plannedRoute: MapRoutePlan
            var directionRequest: MKDirections?

            static func == (lhs: PlannedRouteRequest, rhs: PlannedRouteRequest) -> Bool {
                lhs.plannedRoute == rhs.plannedRoute
            }

            func hash(into hasher: inout Hasher) {
                hasher.combine(plannedRoute)
            }
        }

        init(token: MapLayerToken?, state: MapLayerState, initialPosition: MapLayerVisibleRectInset.Position?, plannedRoutesRequests: OrderedSet<PlannedRouteRequest>, clusterManagers: [MapClusteringIdentifier: MapClusterManager]) {
            self.token = token
            self.initialPosition = initialPosition
            self.configs = state.configs
            self.visibleRectInset = state.visibleRectInset
            self.sidebar = state.sidebar
            self.centerPin = state.centerPin
            self.markers = state.markers
            self.overlays = state.overlays
            self.markerSelection = state.markerSelection

            self.plannedRoutesRequests = plannedRoutesRequests

            self.clusterMarkerProvider = state.clusterMarkerProvider
            self.clusterConfigsProvider = state.clusterConfigsProvider
            self.clusterManagers = clusterManagers
        }

        mutating func update(with newState: MapLayerState, initialPosition: MapLayerVisibleRectInset.Position?, plannedRoutesRequests: OrderedSet<PlannedRouteRequest>, clusterManagers: [MapClusteringIdentifier: MapClusterManager]) {
            self = Layer(token: token, state: newState, initialPosition: initialPosition, plannedRoutesRequests: plannedRoutesRequests, clusterManagers: clusterManagers)
        }
    }

    private enum Annotations {
        /// An approximate expected size of the average annotation (can be adjusted if needed).
        ///
        /// It's used to improve reasoning about touch events on the map,
        /// to help understand if a touch was on the map (i.e. overlay), or on one of the annotations.
        ///
        /// It becomes especially tricky, when annotation's coordinate is out of the screen bounds and close to the edge.
        /// In such case `mapView.annotations(in: mapView.visibleMapRect)` doesn't include this annotation,
        /// even though we can still interact with it.
        ///
        /// So we're using this ~ size to extend `visibleMapRect` when asking for annotations within it.
        static var expectedSize: CGFloat { 50 }

        /// `MKMapView` seems to add extra padding for handling annotation-views touch events.
        /// It ignores any of `MKAnnotationViews` means to achieve this (i.e. `point(inside:with:)` or `hitTest(_:with:)`).
        /// And so this value was figured out empirically.
        static var touchPadding: CGFloat { 5 }
    }

    private lazy var mapView: MKMapView = { AppleMapsView() }()
    private lazy var sidebarView: UIStackView = { UIStackView() }()
    private var centerPinView: UIView?

    private var currentLayer: Layer? = nil
    private var isChangingRegion: Bool = false
    private var fakeLocation: CLLocationCoordinate2D? = nil
    private var sidebarBottomConstraint: NSLayoutConstraint? = nil

    private var userLocation: CLLocationCoordinate2D {
        fakeLocation ?? mapView.userLocation.coordinate
    }

    let layerManager: MapLayerManager<Context>

    private var dynamicLayoutGuideDisposeBag = DisposeBag()
    public weak var dynamicLayoutGuide: MapViewControllerDynamicLayoutGuide? {
        didSet {
            subscribeToDynamicLayoutGuide()
        }
    }

    public init(layerManager: MapLayerManager<Context>) {
        self.layerManager = layerManager

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        configureMap()
        configureSidebarView()

        applyState(.default, with: nil, initialPosition: nil)

        layerManager.delegate = AnyMapLayerManagerDelegate(self)
    }

    public override func viewDidLayoutSubviews() {
        adjustSidebarViewToItsPosition()
    }

    private func subscribeToDynamicLayoutGuide() {
        dynamicLayoutGuideDisposeBag = DisposeBag()

        dynamicLayoutGuide?.mapVerticalInset.asObservable()
            .bind { [weak self] mapVerticalInset in
                self?.setDefaultMapVerticalInset(mapVerticalInset)
            }
            .disposed(by: dynamicLayoutGuideDisposeBag)

        dynamicLayoutGuide?.mapSidebarBottomInset.asObservable()
            .bind { [weak self] sidebarBottomInset in
                self?.setDefaultSidebarBottomInset(sidebarBottomInset)
            }
            .disposed(by: dynamicLayoutGuideDisposeBag)
    }

    private func configureMap() {
        addMapView()

        mapView.delegate = self

        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = .includingAll
        mapView.isPitchEnabled = false
        mapView.showsScale = false
        mapView.userLocation.title = nil

        mapView.insetsLayoutMarginsFromSafeArea = false
        mapView.preservesSuperviewLayoutMargins = false

        mapView.register(AppleMapsMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(AppleMapsClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)

        let touchUpGesture = UITapGestureRecognizer(target: self, action: #selector(onMapDidTap(_:)))
        touchUpGesture.delegate = self
        mapView.addGestureRecognizer(touchUpGesture)
    }

    private func addMapView() {
        view.addSubview(mapView)
        mapView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.bottomAnchor.constraint(equalTo: mapView.bottomAnchor),
            view.trailingAnchor.constraint(equalTo: mapView.trailingAnchor)
        ])
    }

    private func setDefaultMapVerticalInset(_ inset: VerticalInsets) {
        guard let currentLayer = currentLayer else {
            return
        }
        var visibleRectInset = currentLayer.visibleRectInset
        guard visibleRectInset.isAnyAutomatic else {
            return
        }
        if visibleRectInset.top.isAutomatic {
            visibleRectInset.top = .automatic(inset.top)
        }
        if visibleRectInset.bottom.isAutomatic {
            visibleRectInset.bottom = .automatic(inset.bottom)
        }
        // when screen changes its dimensions, it causes vertical insets change,
        // if it happens for the first time during map layer is active, we use `initialPosition` and nulify it immediately afterwards,
        // and for every other time we use `visibleRectInset.position` to reposition map according to new insets.
        let position = currentLayer.initialPosition ?? currentLayer.visibleRectInset.position
        if currentLayer.initialPosition != nil {
            self.currentLayer?.initialPosition = nil
        }
        let prevCenter = mapView.centerCoordinate
        let prevZoom = mapView.zoomLevel
        if applyVisibleRectInset(visibleRectInset, for: self.currentLayer?.token) {
            applyPosition(
                position,
                current: (.init(mapView.centerCoordinate), .init(.zoom(mapView.zoomLevel))),
                state: (.init(prevCenter), .init(.zoom(prevZoom))),
                forNewLayer: false,
                forceUpdate: true
            )
        }
    }

    private func configureSidebarView() {
        addSidebarView()

        sidebarView.axis = .vertical
        sidebarView.alignment = .fill
        sidebarView.distribution = .equalSpacing
        sidebarView.spacing = 8
    }

    private func addSidebarView() {
        view.addSubview(sidebarView)
        sidebarView.translatesAutoresizingMaskIntoConstraints = false

        sidebarBottomConstraint = mapView.bottomAnchor.constraint(equalTo: sidebarView.bottomAnchor, constant: UI.sidebarBottomInset)

        NSLayoutConstraint.activate([
            sidebarBottomConstraint,
            sidebarView.widthAnchor.constraint(equalToConstant: UI.sidebarWidth),
            mapView.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: UI.sidebarRightInset)
        ].compactMap { $0 })
    }

    private func setDefaultSidebarBottomInset(_ bottomInset: CGFloat) {
        sidebarBottomConstraint?.constant = UI.sidebarBottomInset + bottomInset
        // sidebar view's appearance is adjusted to its position in `viewDidLayoutSubviews` to smoothen its UI transitions
    }

    private func adjustSidebarViewToItsPosition() {
        // shrinking sidebar height so that sidebar starts fading-out later, so it looks better on small devices like iPhone 6s
        let shrinkedSidebarHeight = sidebarView.frame.height / 3
        if sidebarView.frame.origin.y - shrinkedSidebarHeight < mapView.layoutMargins.top {
            let distance = sidebarView.frame.origin.y - mapView.layoutMargins.top
            sidebarView.alpha = distance / shrinkedSidebarHeight
        } else {
            sidebarView.alpha = 1
        }
        // disabling user interaction only when sidebar is visibly fading,
        // otherwise if it's faded out just a bit, we allow user interactions,
        // this can be helpful to keep compatibility with small screens like iPhone 6, and so that it doesn't confuse users
        sidebarView.isUserInteractionEnabled = sidebarView.alpha > 0.5
    }

    @objc private func onMapDidTap(_ recognizer: UITapGestureRecognizer) {
        // this method is used to handle tap gesture on the cluster or overlay
        guard recognizer.state == .recognized else {
            return
        }
        let point = recognizer.location(in: mapView)
        // extending `visibleMapRect` to fit annotations that aren't included by it, but are still visible and interactive
        let delta = Annotations.expectedSize
        // annotation view is rendered above its coordinate and centered horizontally, thus corresponding padding
        let extraPadding = UIEdgeInsets(top: 0, left: delta / 2, bottom: delta, right: delta / 2)
        let extendedVisibleMapRect = mapView.mapRectThatFits(mapView.visibleMapRect, edgePadding: extraPadding)
        // it seems that map uses extra spacing aroung annotation view to handle its selection,
        // so we're adding this padding to track annotation touch exclusively.
        let extraTouchPaddingDelta = -1 * Annotations.touchPadding
        // if tap gesture is inside annotation, then it shouldn't be passed to the overlay.
        for annotation in mapView.annotations(in: extendedVisibleMapRect) {
            if let annotationView = markerAnnotationView(for: annotation) {
                if annotationView.frame.insetBy(dx: extraTouchPaddingDelta, dy: extraTouchPaddingDelta).contains(point) {
                    return
                }
            } else if let annotationView = clusterAnnotationView(for: annotation) {
                if annotationView.frame.insetBy(dx: extraTouchPaddingDelta, dy: extraTouchPaddingDelta).contains(point) {
                    if let annotationData = annotationView.annotationData {
                        annotationData.didTap()
                        layerManager.handle(event: .didTapOnCluster(annotationData), for: currentLayer?.token)
                    }
                    return
                }
            }
        }
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        let mapPoint = MKMapPoint(coordinate)
        // once correct overlay is found, notify it and exit
        // iterating overlays in reverse order so that overlays with higher z-index would react earlier
        for overlay in mapView.overlays.reversed() {
            guard
                let overlay = overlay as? AppleMapsOverlay,
                let renderer = mapView.renderer(for: overlay) as? MKOverlayPathRenderer,
                // interior overlays will be explicitly ignored, as they represent an empty area inside of the overlays
                renderer.path.contains(renderer.point(for: mapPoint), using: .evenOdd)
            else {
                continue
            }
            if let overlayData = overlay.overlayData {
                overlayData.didTap(at: coordinate)
                layerManager.handle(event: .didTapInsideOverlay(overlayData, coordinate), for: currentLayer?.token)
            }
            return
        }
        layerManager.handle(event: .didTap(coordinate), for: currentLayer?.token)
    }

    private func markerAnnotationView(for annotation: AnyHashable) -> AppleMapsMarkerAnnotationView? {
        return (annotation as? AppleMapsMarkerAnnotation).flatMap { annotation in
            mapView.view(for: annotation) as? AppleMapsMarkerAnnotationView
        }
    }

    private func clusterAnnotationView(for annotation: AnyHashable) -> AppleMapsClusterAnnotationView? {
        return (annotation as? AppleMapsClusterAnnotation).flatMap { annotation in
            mapView.view(for: annotation) as? AppleMapsClusterAnnotationView
        }
    }

    func mapLayerManager(_ manager: MapLayerManager<Context>, didActivateLayerWithToken token: MapLayerToken, initialState state: MapLayerState, initialPosition: MapLayerVisibleRectInset.Position?) {
        applyState(state, with: token, initialPosition: initialPosition)
    }

    // we rely on the fact, that map layer is used on the main thread, so that everything happens immediately without async wait
    func mapLayerManager(_ manager: MapLayerManager<Context>, didUpdateState state: MapLayerState, forLayerWithToken token: MapLayerToken) {
        applyState(state, with: token, initialPosition: nil)
    }

    private func applyState(_ state: MapLayerState, with token: MapLayerToken?, initialPosition: MapLayerVisibleRectInset.Position?) {
        let isNewLayer = currentLayer.map { $0.token != token } ?? true

        if isNewLayer {
            currentLayer?.token.map(clearMap)
        }
        // preparing state before it is applied and rendered
        var state = state
        prepareStateVisibleRect(&state, isNewLayer: isNewLayer)
        prepareStateCenterCoordinate(&state)
        prepareStateMarkerSelection(&state)
        let markersForClustering = splitMarkersForClustering(&state)
        // applying new state - diffing and rendering
        let prevCenter = mapView.centerCoordinate
        let prevZoom = mapView.zoomLevel
        let isNewInset = applyVisibleRectInset(state.visibleRectInset, for: token)
        applyConfigs(state.configs)
        applySidebar(state.sidebar)
        applyTrackUserSidebarItem(state.isTrackingUser.value)
        // applying position is more complex than other properties because it involves different factors,
        // like whether visible rect insets were changed, or whether layer has already applied initially requested position, etc.
        if currentLayer?.initialPosition == nil, isNewInset {
            applyPosition(
                state.visibleRectInset.position,
                // if by any reason both visible rect insets and a new center coordinate or zoom were changed simultaneously,
                // then we, of course, will use new state's center or zoom, instead of what mapView previously had
                current: (
                    prevCenter.isCloseTo(state.centerCoordinate.value) ? .init(mapView.centerCoordinate) : state.centerCoordinate,
                    prevZoom == state.zoomLevel.value.zoom ? .init(.zoom(mapView.zoomLevel)) : state.zoomLevel
                ),
                state: (state.centerCoordinate, state.zoomLevel),
                forNewLayer: isNewLayer,
                forceUpdate: true
            )
        } else {
            applyPosition(center: state.centerCoordinate, zoomLevel: state.zoomLevel, forNewLayer: isNewLayer, forceUpdate: false)
        }
        applyUserTracking(state.isTrackingUser)
        applyHeading(state.heading)
        applyCenterPin(state.centerPin)
        replaceOverlays(with: state.overlays, for: token)
        replaceMarkers(with: state.markers, for: token)
        let newPlannedRoutesRequests = updatedPlannedRoutesRequests(with: state.plannedRoutes, for: token)
        let newClusterManagers = updatedClusterManagers(
            with: markersForClustering,
            clusterMarkerProvider: state.clusterMarkerProvider,
            clusterConfigsProvider: state.clusterConfigsProvider,
            for: token
        )
        let oldSelection: MapMarkerSelection?
        if isNewLayer {
            oldSelection = nil
            currentLayer = Layer(token: token, state: state, initialPosition: initialPosition, plannedRoutesRequests: newPlannedRoutesRequests, clusterManagers: newClusterManagers)
        } else {
            oldSelection = currentLayer?.markerSelection
            let initialPosition = currentLayer?.initialPosition
            currentLayer?.update(with: state, initialPosition: initialPosition, plannedRoutesRequests: newPlannedRoutesRequests, clusterManagers: newClusterManagers)
        }
        // Selecting/Deselecting and especially Reselecting a marker is quite tricky process in MKMapView.
        // Reselecting a marker from M1 to M2 is split into 4 steps:
        //   1. M1: MKMapViewDelegate - mapView:didDeselect
        //   2. M1: MKAnnotationView - setSelected:false
        //   3. M2: MKMapViewDelegate - mapView:didSelect
        //   4. M2: MKAnnotationView - setSelected:true
        // And once first (M1) marker is deselected, it's impossible to know whether it's a full marker deselection,
        // or if it's an intermediate step when re-selecting a different marker (M2).
        // So we need to have as much knowledge of the full process as possible,
        // desirably without introducing additional intermediate variables that would need to be supported as well.
        // Thus we're selecting marker after we've updated `currentLayer`.
        // This way we'll have currentLayer as a final state we're trying to achieve and MKMapView as a current state at each step.
        // See `handleSelectionEvent` and `applyMarkerSelection` for the actual magic.
        applyMarkerSelection(from: oldSelection, to: currentLayer?.markerSelection)
        calculatePlannedRoutesRequests(with: newPlannedRoutesRequests)
    }

    private func prepareStateVisibleRect(_ state: inout MapLayerState, isNewLayer: Bool) {
        // Applying automatic visible rect insets, that don't have any value yet, i.e. `.default(.none)`
        guard state.visibleRectInset.isAnyAutomatic else {
            return
        }
        // This fixes a case when we return from a scene (B) to a previous one (A), where (A) has automatic visibleRectInset,
        // so we don't mess up insets (A), by setting inset from the scene (B).
        // There're two actions that happen in sequence:
        // 1. request control for the previous scene layer (A)
        // between 1 and 2. apply scene (A) map layer
        // 2. present corresponding scene (A)
        // and when we're applying a layer from the scene (A), we're still having scene (B) shown (between step 1 and 2),
        // which tries to set inset from scene (B) to a map layer of scene (A),
        // and to prevent this from happening we won't apply visible inset in this case.
        if isNewLayer && state.visibleRectInset.top.value != nil && state.visibleRectInset.bottom.value != nil {
            return
        }

        let newInset = dynamicLayoutGuide.map(\.mapVerticalInset.value) ?? .zero
        if state.visibleRectInset.top.isAutomatic {
            state.visibleRectInset.top = .automatic(newInset.top)
        }
        if state.visibleRectInset.bottom.isAutomatic {
            state.visibleRectInset.bottom = .automatic(newInset.bottom)
        }
    }

    private func prepareStateCenterCoordinate(_ state: inout MapLayerState) {
        // whenever user-tracking is on, we should not allow different center coordinate than the user's location, to be set;
        //
        // that's why, if new state center coordinate significantly differs from what we currently have with user-tracking on,
        // we reset it to current coordinate on the map, and adjust user-tracking animation in case either of them should be animated;
        //
        // by resetting new state's center to current map's center, we don't trigger map's regions changes
        // and allow user-tracking to take effect smoothly with animation if needed,
        // as well as to set desired zoom level even if custom center coordinate couldn't be applied because of user-tracking.
        //
        // tl;dr: even with custom center but user-tracking on - track user (with animation if needed) and apply desired zoom level.
        guard state.isTrackingUser.value && state.centerCoordinate.value.isNotCloseTo(userLocation) else {
            return
        }
        if state.centerCoordinate.animated || state.isTrackingUser.animated {
            state.isTrackingUser.setValue(true, animated: true)
        }
        state.centerCoordinate.setValue(mapView.centerCoordinate, animated: false)
    }

    private func prepareStateMarkerSelection(_ state: inout MapLayerState) {
        // this is a fix for keeping marker selected after clearing the map:
        //
        // when annotation is removed from MKMapView, its annotation view gets deselected and thus it deselects marker,
        // which is totally fine in most of the cases...
        //
        // but there's a case when we clear the map because new layer takes control or because current one has relinquished it,
        // in that case map layer keeps marker selection as it was left (once layer is inactive, it stops receiving map callbacks),
        // however marker isSelected flag switches to false, because its annotation view gets deselected.
        // at this point layer keeps selection value pointing to that marker, however marker's flag is false (they're desynced).
        //
        // usually it'd pass unnoticed except for one case when selected marker belongs to a cluster, and map is zoomed out,
        // in that case we want to keep selected marker on the map instead of grouping it into cluster,
        // but cluster renderer doesn't know that marker is selected (because its flag is false) and so it is grouped into cluster.
        //
        // to fix this issue, we make sure that selection has already happened (isSelected), and thus toggle the actual marker's flag
        // if it's in a different state (even though we're using `setSelected` internal API) ¯\_(ツ)_/¯
        if let selection = state.markerSelection, selection.isSelected, !selection.value.isSelected.value {
            selection.value.setSelected(true)
        }
    }

    /// Will update state with non-clustering markers, and return markers that are intended for clustering.
    private func splitMarkersForClustering(_ state: inout MapLayerState) -> Set<MapMarker> {
        var nonClusteringMarkers: Set<MapMarker> = []
        var clusteringMarkers: Set<MapMarker> = []
        for marker in state.markers {
            if marker.clusteringIdentifier == nil {
                nonClusteringMarkers.insert(marker)
            } else {
                clusteringMarkers.insert(marker)
            }
        }
        state.markers = nonClusteringMarkers
        return clusteringMarkers
    }

    private func applyConfigs(_ configs: MapConfigs) {
        guard currentLayer?.configs != configs else { return }

        mapView.isScrollEnabled = configs.contains(.isScrollEnabled)
        mapView.isRotateEnabled = configs.contains(.isRotateEnabled)
        mapView.isZoomEnabled = configs.contains(.isZoomEnabled)
        mapView.showsCompass = configs.contains(.showsCompass)
        mapView.showsUserLocation = configs.contains(.showsUserLocation)
        mapView.showsBuildings = configs.contains(.isBuildingsEnabled)
        mapView.showsTraffic = configs.contains(.isTrafficEnabled)
        mapView.pointOfInterestFilter = configs.contains(.isPOIsEnabled)
            ? .includingAll
            : .excludingAll
    }

    private func applySidebar(_ sidebar: MapSidebar) {
        guard currentLayer?.sidebar != sidebar else { return }

        sidebarView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        sidebar.reversed().forEach { sidebarItem in
            let button = MapSidebarItemButton(item: sidebarItem)
            _ = button.rx.tap.take(until: button.rx.deallocated).bind { [weak self] in
                guard let self = self else { return }
                // might seem a bit hacky:
                // in case we don't have real active layer (the one with the token),
                // we kinda still want to preserve user tracking feature, thus we handle it here.
                //
                // however if current layer belongs to someone, we let them decide.
                if self.currentLayer?.token == nil, case .trackUser = sidebarItem {
                    self.applyUserTracking(Animatable(true, animated: true))
                }
                self.layerManager.handle(event: .didTapSidebarItem(sidebarItem), for: self.currentLayer?.token)
            }
            sidebarView.addArrangedSubview(button)
        }
    }

    private func applyTrackUserSidebarItem(_ isTrackingUser: Bool) {
        guard let view = sidebarView.arrangedSubviews.compactMap({ $0 as? MapSidebarItemButton }).first(where: \.item.isTrackUser) else { return }
        view.updateContent(isHighlighted: isTrackingUser)
    }

    @discardableResult
    private func applyVisibleRectInset(_ inset: MapLayerVisibleRectInset, for token: MapLayerToken?) -> Bool {
        guard currentLayer?.visibleRectInset != inset else {
            return false
        }
        mapView.layoutMargins = UIEdgeInsets(
            top: inset.top.value ?? .zero,
            left: UI.logoAndLegalHorizontalInset,
            bottom: inset.bottom.value ?? .zero,
            right: UI.logoAndLegalHorizontalInset
        )
        currentLayer?.visibleRectInset = inset
        // need to apply changes immediately so that it happens synchronously
        view.layoutIfNeeded()
        layerManager.handle(event: .didUpdateVisibleRectInset(inset), for: token)
        return true
    }

    /// Applies position relying on both existing and new arguments of center and zoom values.
    private func applyPosition(
        _ position: MapLayerVisibleRectInset.Position,
        current: (center: Animatable<CLLocationCoordinate2D>, zoom: Animatable<MapZoomLevel>),
        state: (center: Animatable<CLLocationCoordinate2D>, zoom: Animatable<MapZoomLevel>),
        forNewLayer: Bool,
        forceUpdate: Bool
    ) {
        switch position {
        case .absolute:
            applyPosition(center: current.center, zoomLevel: current.zoom, forNewLayer: forNewLayer, forceUpdate: forceUpdate)
        case .relative:
            applyPosition(center: state.center, zoomLevel: state.zoom, forNewLayer: forNewLayer, forceUpdate: forceUpdate)
        case .coordinateOnly:
            applyPosition(center: state.center, zoomLevel: current.zoom, forNewLayer: forNewLayer, forceUpdate: forceUpdate)
        }
    }

    private func applyPosition(center: Animatable<CLLocationCoordinate2D>, zoomLevel: Animatable<MapZoomLevel>, forNewLayer: Bool, forceUpdate: Bool) {
        guard !isChangingRegion else {
            return
        }
        guard CLLocationCoordinate2DIsValid(center.value) else {
            // this will trigger a notification of position change to whatever map currently points to,
            // otherwise, if there were no interactions with the map it would keep invalid coordinate,
            // which is wrong, because layer should become up to date with the real map, once it's active
            return mapView.setCenter(mapView.centerCoordinate, animated: false)
        }
        // if zoom has changed, it means we need to specify center anyways
        if (zoomLevel.value.zoom.map(mapView.zoomLevel.isNotCloseTo) ?? true) || forceUpdate {
            switch zoomLevel.value {
            case let .zoom(zoomValue):
                mapView.setCenterCoordinate(center.value, zoomLevel: zoomValue, animated: zoomLevel.animated && !forNewLayer)

            case let .span(span, padding):
                let paddingFactor = padding.factor == 0 ? 1 : padding.factor
                let region = MKCoordinateRegion(
                    center: center.value,
                    span: MKCoordinateSpan(
                        latitudeDelta: span.latitudeDelta * paddingFactor,
                        longitudeDelta: span.longitudeDelta * paddingFactor
                    )
                )
                let validRegion: MKCoordinateRegion
                if padding.insets == .zero {
                    validRegion = mapView.regionThatFits(region)
                } else {
                    let rect = MKMapRect(region)
                    let validRect = mapView.mapRectThatFits(rect, edgePadding: padding.insets)
                    validRegion = mapView.regionThatFits(MKCoordinateRegion(validRect))
                }
                guard CLLocationCoordinate2DIsValid(validRegion.center),
                      !validRegion.span.latitudeDelta.isNaN,
                      !validRegion.span.longitudeDelta.isNaN
                else {
                    return mapView.setCenter(mapView.centerCoordinate, animated: false)
                }
                mapView.setRegion(validRegion, animated: zoomLevel.animated && !forNewLayer)
            }
        } else if center.value.isNotCloseTo(mapView.centerCoordinate) {
            mapView.setCenter(center.value, animated: center.animated && !forNewLayer)
        }
        // when we're force-updating position, it should be updated in the layer as well,
        // as it can be triggered by other sources than the layer changes (i.e. updated vertical insets),
        // so we make sure to update layer if map itself won't trigger any delegate updates.
        if forceUpdate && mapView.centerCoordinate.isCloseTo(center.value) {
            layerManager.handle(
                event: .changingPosition(
                    status: .ended,
                    center: mapView.centerCoordinate,
                    zoom: mapView.zoomLevel,
                    heading: mapView.camera.heading,
                    span: .init(latitudeDelta: mapView.region.span.latitudeDelta, longitudeDelta: mapView.region.span.longitudeDelta)
                ),
                for: currentLayer?.token
            )
        }
    }

    private func applyHeading(_ heading: Animatable<CLLocationDirection>) {
        // we should copy existing camera to update map heading with animation
        guard heading.value.isNotCloseTo(mapView.camera.heading), let camera = mapView.camera.copy() as? MKMapCamera else {
            return
        }
        camera.heading = heading.value
        // if region change is already in progress, rotate camera without animation,
        // otherwise it would break that region change
        mapView.setCamera(camera, animated: heading.animated && !isChangingRegion)
    }

    private func applyUserTracking(_ isTrackingUser: Animatable<Bool>) {
        if isTrackingUser.value {
            // if we're faking location, just set map center location as fake location if we want to "track user",
            // otherwise follow them the normal way
            if let fakeLocation = fakeLocation {
                mapView.setCenter(fakeLocation, animated: isTrackingUser.animated)
            } else if !mapView.userTrackingMode.isTrackingUser {
                mapView.setUserTrackingMode(.follow, animated: isTrackingUser.animated)
            }
        } else if mapView.userTrackingMode.isTrackingUser {
            mapView.setUserTrackingMode(.none, animated: isTrackingUser.animated)
        }
    }

    private func applyCenterPin(_ centerPin: MapMarker.Content?) {
        guard currentLayer?.centerPin != centerPin else {
            return
        }
        centerPinView?.removeFromSuperview()
        switch centerPin?.icon {
        case let .image(image):
            centerPinView = UIImageView(image: image.value)
        case let .view(view):
            centerPinView = view
        case .none:
            centerPinView = nil
        }
        guard let centerPinView = centerPinView, let offset = centerPin?.centerOffset else {
            return
        }
        mapView.addSubview(centerPinView)
        centerPinView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerPinView.centerXAnchor.constraint(equalTo: mapView.layoutMarginsGuide.centerXAnchor, constant: offset.x),
            centerPinView.centerYAnchor.constraint(equalTo: mapView.layoutMarginsGuide.centerYAnchor, constant: offset.y - centerPinView.bounds.size.height / 2),
//            centerPinView.widthAnchor.constraint(equalToConstant: centerPinView.bounds.size.width),
//            centerPinView.heightAnchor.constraint(equalToConstant: centerPinView.bounds.size.height)
        ])
    }

    private func replaceMarkers(with newMarkers: Set<MapMarker>, for token: MapLayerToken?) {
        // no need to bother if nothing changed
        guard currentLayer?.markers != newMarkers else {
            return
        }
        // can't add annotations without token or if new markers are empty, so just remove all for the previous layer
        guard let token = token, !newMarkers.isEmpty else {
            return mapView.removeAnnotations(mapView.annotations.filter {
                // notice, that we don't touch markers with clustering identifier here, they're managed by corresponding cluster managers
                ($0 as? AppleMapsMarkerAnnotation)?.data.clusteringIdentifier == nil
            })
        }
        // constructing dictionary for faster lookup of annotations by their markers
        let oldMarkersAnnotations = mapView.annotations.reduce(into: [MapMarker: AppleMapsMarkerAnnotation]()) { acc, annotation in
            // notice, that we don't touch markers with clustering identifier here, they're managed by corresponding cluster managers
            if let annotation = annotation as? AppleMapsMarkerAnnotation, annotation.data.clusteringIdentifier == nil {
                acc[annotation.data] = annotation
            }
        }
        // there will be many markers on the map at the same time,
        // so we try to make it as seamless as possible by diffing markers and adding/removing only those that need to;
        // their order doesn't matter, so we just leave common markers in whatever order they are.
        let oldMarkers = Set(oldMarkersAnnotations.keys)
        let toRemove = oldMarkers.subtracting(newMarkers)
        let toAdd = newMarkers.subtracting(oldMarkers)
        // adding and removing annotations based on their markers diff
        mapView.removeAnnotations(toRemove.compactMap { oldMarkersAnnotations[$0] })
        mapView.addAnnotations(toAdd.map { AppleMapsMarkerAnnotation(marker: $0, layerToken: token) })
    }

    private func replaceOverlays(with newOverlays: OrderedSet<MapOverlay>, for token: MapLayerToken?) {
        // no need to bother if nothing changed
        guard currentLayer?.overlays != newOverlays else { return }
        // assuming we don't have many overlays on the map simultaneously,
        // it might be much easier to just remove all old overlays and add new ones in correct order,
        // instead of diffing and swapping their positions (MapKit doesn't provide good tools for this \wo removing renderers).
        //
        // let's see how it works, and if UX is bad, we'll use some diffing algorithm to improve it.
        mapView.removeOverlays(mapView.overlays.compactMap { overlay -> MKOverlay? in
            if let data = (overlay as? AppleMapsOverlay)?.overlayData {
                return currentLayer?.overlays.contains(data) == true ? overlay : nil
            }
            return nil
        })
        // can't add overlays without token, so just leave with removed ones
        if let token = token {
            mapView.addOverlays(newOverlays.map { overlay in
                switch overlay {
                case let .polyline(polyline): return AppleMapsPolyline(polyline: polyline, layerToken: token)
                case let .polygon(polygon): return AppleMapsPolygon(polygon: polygon, layerToken: token)
                case let .circle(circle): return AppleMapsCircle(circle: circle, layerToken: token)
                }
            })
        }
    }

    private func applyMarkerSelection(from oldSelection: MapMarkerSelection?, to newSelection: MapMarkerSelection?) {
        guard oldSelection != newSelection else {
            return
        }
        handleMarkerSelection(with: newSelection)
    }

    private func handleMarkerSelection(with markerSelection: MapMarkerSelection?) {
        // please note that all selections and deselections are executed here without animations to happen immediately.
        switch markerSelection {
        case .none:
            if let selectedAnnotation = mapView.selectedAnnotations.first(where: { $0 is AppleMapsMarkerAnnotation }) {
                mapView.deselectAnnotation(selectedAnnotation, animated: false)
            }
        case let .selecting(markerToSelect):
            if let annotaion = mapView.annotations.first(where: { ($0 as? AppleMapsMarkerAnnotation)?.data == markerToSelect }) {
                mapView.selectAnnotation(annotaion, animated: false)
            } else if let clusteringIdentifier = markerToSelect.clusteringIdentifier {
                // deselecting selected marker first if such exists, to not keep both selected and the one we choose here.
                handleMarkerSelection(with: .none)
                // if there's no such marker's annotation among those that are currently on the map,
                // it means that it can be as well clustered, and we won't be able to select it until it's on the map.
                //
                // thus we try to recluster its group and see if it can be excluded from any cluster and rendered as marker instead.
                currentLayer?.clusterManagers[clusteringIdentifier]?.cluster(except: markerToSelect)
                // and then we try to select it again,
                // however we don't call this method recursively to not overflow the stack if there's some problem with this marker.
                if let annotaion = mapView.annotations.first(where: { ($0 as? AppleMapsMarkerAnnotation)?.data == markerToSelect }) {
                    mapView.selectAnnotation(annotaion, animated: false)
                }
            }
        case let .selected(selectedMarker):
            guard !mapView.selectedAnnotations.contains(where: { ($0 as? AppleMapsMarkerAnnotation)?.data == selectedMarker }) else {
                break
            }
            // if map doesn't have given marker selected by any means (i.e. map layer re-activated),
            // treat it as in progress of selection and re-try operation
            handleMarkerSelection(with: .selecting(selectedMarker))
        }
    }

    private func updatedPlannedRoutesRequests(with newPlannedRoutes: OrderedSet<MapRoutePlan>, for token: MapLayerToken?) -> OrderedSet<Layer.PlannedRouteRequest> {
        let oldRequests = currentLayer?.plannedRoutesRequests ?? []
        var currentRequests = oldRequests
        // no requests, no anything if there's no token, thus cancel current requests and remove them by returning empty updated dict
        guard let token = token else {
            currentRequests.forEach { $0.directionRequest?.cancel() }
            return []
        }
        let isSameLayer = currentLayer?.token == token
        let zoomLevel = mapView.zoomLevel
        let newPolylines = newPlannedRoutes.flatMap { plannedRoute -> OrderedSet<MapPolyline> in
            return plannedRoute.rendering.shouldDisplayPolylines(at: zoomLevel)
                ? plannedRoute.polylines ?? []
                : []
        }

        guard isSameLayer else {
            currentRequests.forEach { $0.directionRequest?.cancel() }
            // in case it's a new layer, old polylines were already removed with `clearMap`, so we can easily add new
            mapView.addOverlays(newPolylines.map { AppleMapsPolyline(polyline: $0, layerToken: token) })
            // there might be a case when a layer was deactivated before routes finished calculating,
            // hence they will keep their previous `calculating` status but will loose the actual progress,
            // so we drop their status locally to `idle` and assign a new progress to start from scratch
            return newPlannedRoutes.reduce(into: []) { acc, plannedRoute in
                var plannedRoute = plannedRoute
                if !plannedRoute.status.isFinished {
                    plannedRoute.status = .idle
                }
                acc.append(Layer.PlannedRouteRequest(
                    plannedRoute: plannedRoute,
                    directionRequest: plannedRoute.status.isIdle ? MKDirections(plannedRoute: plannedRoute) : nil
                ))
            }
        }
        // diff requests by planned routes
        let oldPlannedRoutesRequests = currentRequests.reduce(into: [:]) { acc, plannedRouteRequest in
            acc[plannedRouteRequest.plannedRoute] = plannedRouteRequest.directionRequest
        }
        let oldPlannedRoutes = Set(oldPlannedRoutesRequests.keys)
        let toRemove = oldPlannedRoutes.subtracting(newPlannedRoutes)
        // cancel unneded requests and remove them, both from the layer and from the map
        for plannedRoute in toRemove {
            oldPlannedRoutesRequests[plannedRoute]?.cancel()
            currentRequests.remove(.init(plannedRoute: plannedRoute, directionRequest: oldPlannedRoutesRequests[plannedRoute]))
        }
        // create new or update existing requests, based on newcomers
        for plannedRoute in newPlannedRoutes {
            let directionRequest = oldPlannedRoutesRequests[plannedRoute]
                ?? (plannedRoute.status.isIdle ? MKDirections(plannedRoute: plannedRoute) : nil)
            // updating each and every existing planned route with new one even if they are `equal`,
            // to update their secondary properties like `status` and `polylines`
            currentRequests.updateOrAppend(Layer.PlannedRouteRequest(
                plannedRoute: plannedRoute,
                directionRequest: directionRequest
            ))
        }
        // diffing polylines to understand if they need to be re-rendered
        let oldPolylines = oldRequests.flatMap { $0.plannedRoute.polylines ?? [] }
        if oldPolylines != newPolylines {
            // just like in `replaceOverlays`, we assume there're not many routes simultaneously,
            // so we can delete them all and add new to preserve the order
            mapView.removeOverlays(mapView.overlays.compactMap { overlay -> MKOverlay? in
                guard let polyline = (overlay as? AppleMapsPolyline)?.data else {
                    return nil
                }
                return oldPolylines.contains(polyline) ? overlay : nil
            })
            mapView.addOverlays(newPolylines.map { AppleMapsPolyline(polyline: $0, layerToken: token) })
        }

        return currentRequests
    }

    private func calculatePlannedRoutesRequests(with plannedRoutesRequests: OrderedSet<Layer.PlannedRouteRequest>) {
        guard let currentLayerToken = currentLayer?.token else {
            return
        }
        typealias CalculationObservable = Observable<(plannedRoute: MapRoutePlan, result: Result<MapRoutePlan.Response, NSError>)>
        typealias StartedCalculatingRoutes = (plannedRoute: MapRoutePlan, calculation: CalculationObservable)

        let startedCalculatingRoutes = plannedRoutesRequests
            .compactMap { plannedRouteRequest -> StartedCalculatingRoutes? in
                guard plannedRouteRequest.plannedRoute.status.isIdle else {
                    return nil
                }
                guard let directionRequest = plannedRouteRequest.directionRequest, !directionRequest.isCalculating else {
                    return nil
                }
                let plannedRoute = plannedRouteRequest.plannedRoute
                let calculation = directionRequest.rx.calculate()
                    .asObservable()
                    .flatMap { response -> CalculationObservable in
                        if let route = response.routes.first {
                            return .just((plannedRoute, .success(MapRoutePlan.Response(route: route))))
                        } else {
                            return .error(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil))
                        }
                    }
                    .catch({ error in
                        return .just((plannedRoute, .failure(error as NSError)))
                    })
                return (plannedRoute, calculation)
            }

        guard !startedCalculatingRoutes.isEmpty else {
            return
        }

        _ = Observable.zip(startedCalculatingRoutes.map(\.calculation))
            .take(1)
            .map { calculationResults in
                calculationResults.reduce(into: [:]) { acc, calculationResult in
                    acc[calculationResult.plannedRoute] = calculationResult.result
                }
            }
            .subscribe(onNext: { [weak self] calculationsResult in
                self?.layerManager.handle(event: .didFinishCalculatingRoutes(calculationsResult), for: currentLayerToken)
            })

        layerManager.handle(event: .didStartCalculatingRoutes(startedCalculatingRoutes.map(\.plannedRoute)), for: currentLayerToken)
    }

    private func updatedClusterManagers(
        with newMarkers: Set<MapMarker>,
        clusterMarkerProvider: MapClusterMarkerProvider?,
        clusterConfigsProvider: MapClusterConfigsProvider?,
        for token: MapLayerToken?
    ) -> [MapClusteringIdentifier: MapClusterManager] {
        var currentManagers = currentLayer?.clusterManagers ?? [:]
        // no cluster, no anything if there's no token, thus clear current managers and remove them by returning empty updated dict
        guard let token = token else {
            currentManagers.values.forEach { $0.clearItems() }
            return [:]
        }
        let isSameLayer = currentLayer?.token == token
        // group markers that need to be clustured by their clustering identifier
        let newClustersById = newMarkers.reduce(into: [MapClusteringIdentifier: Set<MapMarker>]()) { acc, marker in
            if let cluseringId = marker.clusteringIdentifier {
                acc[cluseringId, default: []].insert(marker)
            }
        }
        guard isSameLayer else {
            currentManagers.values.forEach { $0.clearItems() }

            return newClustersById.reduce(into: [:]) { acc, markersById in
                let manager = MapClusterManager.makeNonHierarchicalDistanceBased(
                    identifier: markersById.key,
                    layerToken: token,
                    mapView: mapView,
                    clusterMarkerProvider: clusterMarkerProvider,
                    clusterConfigsProvider: clusterConfigsProvider
                )
                manager.replaceItems(with: markersById.value)
                acc[markersById.key] = manager
            }
        }
        // diff managers by clustering identifiers
        let oldClusterIds = Set(currentManagers.keys)
        let newClusterIds = Set(newClustersById.keys)
        let toAdd = newClusterIds.subtracting(oldClusterIds)
        let toRemove = oldClusterIds.subtracting(newClusterIds)
        // if token hasn't changed, don't remove maanagers, just clear them instead
        for clusteringId in toRemove {
            // we don't need to remove managers with everything they have (quad-trees, caches, etc.),
            // if we happen to receive new markers without some of the previous clustering groups, even for a moment
            // we'll still keep empty managers during a single layer workflow.
            currentManagers[clusteringId]?.clearItems()
        }
        // create new managers for the new tokens
        for clusteringId in toAdd {
            currentManagers[clusteringId] = .makeNonHierarchicalDistanceBased(
                identifier: clusteringId,
                layerToken: token,
                mapView: mapView,
                clusterMarkerProvider: clusterMarkerProvider,
                clusterConfigsProvider: clusterConfigsProvider
            )
        }
        // update managers with the corresponding markes grouped by clustering identifier
        for (clusteringId, markers) in newClustersById {
            currentManagers[clusteringId]?.replaceItems(with: markers)
        }
        // apply cluster markers provider if it's different or if we're on a new layer
        if currentLayer?.clusterMarkerProvider != clusterMarkerProvider {
            currentManagers.values.forEach {
                $0.renderer.clusterMarkerProvider = clusterMarkerProvider
            }
        }
        // apply cluster configs provider if it's different or if we're on a new layer
        if currentLayer?.clusterConfigsProvider != clusterConfigsProvider {
            currentManagers.values.forEach {
                $0.renderer.clusterConfigsProvider = clusterConfigsProvider
            }
        }
        return currentManagers
    }

    private func clearMap(for token: MapLayerToken) {
        isChangingRegion = false
        currentLayer?.plannedRoutesRequests.forEach { $0.directionRequest?.cancel() }
        currentLayer?.clusterManagers.values.forEach { $0.clearItems() }
        mapView.removeAnnotations(mapView.annotations.filter { ($0 as? AppleMapsMarkerAnnotation)?.layerToken == token })
        mapView.removeOverlays(mapView.overlays.filter { ($0 as? AppleMapsOverlay)?.layerToken == token })
        centerPinView?.removeFromSuperview()
    }

    func mapLayerManager(_ manager: MapLayerManager<Context>, didRelinquishActiveLayerWithToken token: MapLayerToken) {
        guard let currentLayer = currentLayer, currentLayer.token == token else {
            return
        }
        // if there's no layer to control the map, we preserve positional properties and reset its other configs to defaults
        applyState(MapLayerState(
            configs: MapConfig.allWithoutMapDetails,
            visibleRectInset: currentLayer.visibleRectInset,
            sidebar: [.trackUser(highlightedContent: nil, normalContent: nil)],
            markers: [],
            overlays: [],
            markerSelection: nil,
            plannedRoutes: [],
            zoomLevel: Animatable(.zoom(mapView.zoomLevel), animated: false),
            centerCoordinate: Animatable(mapView.centerCoordinate, animated: false),
            heading: Animatable(mapView.camera.heading, animated: false),
            isTrackingUser: Animatable(mapView.userTrackingMode.isTrackingUser, animated: false),
            clusterMarkerProvider: nil,
            clusterConfigsProvider: nil
        ), with: nil, initialPosition: nil)
    }

    public func setFakeLocation(_ fakeCoordinate: CLLocationCoordinate2D?) {
        let newFakeLocation = fakeCoordinate.filter(by: CLLocationCoordinate2DIsValid)
        let shouldTrackUser = newFakeLocation == nil && fakeLocation != nil
        fakeLocation = newFakeLocation
        // if we're dropping fake location from some value to none, we should go back to current user location,
        // and it doesn't matter if user is currently scrolling the map (isChangingRegion = true) or not.
        //
        // otherwise just go to the new fake location.
        if let fakeLocation = fakeLocation {
            mapView.setCenter(fakeLocation, animated: true)
        } else if shouldTrackUser {
            mapView.setUserTrackingMode(.follow, animated: true)
        }
    }

    // MARK: MKMapViewDelegate

    public func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        isChangingRegion = true
        layerManager.handle(
            event: .changingPosition(
                status: .starting,
                center: mapView.centerCoordinate,
                zoom: mapView.zoomLevel,
                heading: mapView.camera.heading,
                span: .init(latitudeDelta: mapView.region.span.latitudeDelta, longitudeDelta: mapView.region.span.longitudeDelta)
            ),
            for: currentLayer?.token
        )
        // in case of fake location
        // we don't care whether location is changing because user is scrolling the map, or because we're showing fake location,
        // it's static anyway and is needed only for local testing purposes, so it's totally ok to drop user tracking.
        if fakeLocation != nil {
            layerManager.handle(event: .didUpdateUserTracking(false), for: currentLayer?.token)
        }
    }

    public func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        // `regionWillChangeAnimated` will always be called and will always set `isChangingRegion` into `true`,
        // the only time it can be false here is when we clear the map in case of switching between layers,
        // and this guard helps us to not transfer coordinate from the previous layer when it's not needed;
        // in short if you spin the map and quickly switch layer, it was transferred to the new layer because it was still in motion.
        guard isChangingRegion else {
            return
        }
        layerManager.handle(
            event: .changingPosition(
                status: .inProgress,
                center: mapView.centerCoordinate,
                zoom: mapView.zoomLevel,
                heading: mapView.camera.heading,
                span: .init(latitudeDelta: mapView.region.span.latitudeDelta, longitudeDelta: mapView.region.span.longitudeDelta)
            ),
            for: currentLayer?.token
        )
    }

    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // same reason for this guard as in case of `mapViewDidChangeVisibleRegion`
        guard isChangingRegion else {
            return
        }
        isChangingRegion = false
        let zoomLevel = mapView.zoomLevel
        layerManager.handle(
            event: .changingPosition(
                status: .ended,
                center: mapView.centerCoordinate,
                zoom: zoomLevel,
                heading: mapView.camera.heading,
                span: .init(latitudeDelta: mapView.region.span.latitudeDelta, longitudeDelta: mapView.region.span.longitudeDelta)
            ),
            for: currentLayer?.token
        )
        handlePlannedRoutesRenderingStrategy(for: zoomLevel)
    }

    private func handlePlannedRoutesRenderingStrategy(for zoomLevel: Double) {
        // checking if current layer is still active due to one corner case,
        // when you could spin the map with planned routes rendered, and quickly switch to the next map layer,
        // in that case map was still in motion even during intermediate phase when switching between old and new layers in `applyState`.
        // this led to this method being called inbetween and thus rendering overlays from previous layer.
        guard let layerToken = currentLayer?.token, layerManager.isLayerActive(with: layerToken) else {
            return
        }
        let currentOverlays: [MapPolyline: MKOverlay] = mapView.overlays.reduce(into: [:]) { acc, overlay in
            guard let polylineOverlay = overlay as? AppleMapsPolyline, let polyline = polylineOverlay.data else {
                return
            }
            acc[polyline] = overlay
        }
        currentLayer?.plannedRoutesRequests.forEach { plannedRouteRequest in
            guard let polylines = plannedRouteRequest.plannedRoute.polylines, plannedRouteRequest.plannedRoute.rendering != .always else {
                return
            }
            // display only those that are not yet on the map, to not duplicate overlays
            if plannedRouteRequest.plannedRoute.rendering.shouldDisplayPolylines(at: zoomLevel) {
                mapView.addOverlays(polylines.compactMap { polyline in
                    return currentOverlays[polyline] == nil
                        ? AppleMapsPolyline(polyline: polyline, layerToken: layerToken)
                        : nil
                })
            } else {
                mapView.removeOverlays(polylines.compactMap { currentOverlays[$0] })
            }
        }
    }

    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? AppleMapsMarkerAnnotation {
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier) as? AppleMapsMarkerAnnotationView
            annotationView?.annotation = annotation
            return annotationView ?? AppleMapsMarkerAnnotationView(annotation: annotation, reuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        } else if let annotation = annotation as? AppleMapsClusterAnnotation {
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier) as? AppleMapsClusterAnnotationView
            annotationView?.annotation = annotation
            return annotationView ?? AppleMapsClusterAnnotationView(annotation: annotation, reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        }
        return nil
    }

    public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        switch overlay {
        case let polyline as AppleMapsPolyline:
            return AppleMapsPolylineRenderer(polyline: polyline)
        case let polygon as AppleMapsPolygon:
            return AppleMapsPolygonRenderer(polygon: polygon)
        case let circle as AppleMapsCircle:
            return AppleMapsCircleRenderer(circle: circle)
        default:
            return MKOverlayRenderer(overlay: overlay)
        }
    }

    public func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        // disable selecting user location, as it can be pretty annoying
        mapView.view(for: mapView.userLocation)?.isEnabled = false
    }

    public func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
        layerManager.handle(event: .didUpdateUserTracking(mode.isTrackingUser), for: currentLayer?.token)
        applyTrackUserSidebarItem(mode.isTrackingUser)
    }

    public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        handleSelectionEvent(for: view, selected: true)
    }

    public func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        handleSelectionEvent(for: view, selected: false)
    }

    // TODO: Think again if it's possible to avoid notifying map layer of intermediate step when re-selecting marker,
    //       so that there's no deselect notification in that case

    private func handleSelectionEvent(for view: MKAnnotationView, selected: Bool) {
        guard let annotationView = view as? AppleMapsMarkerAnnotationView, let marker = annotationView.annotationData else {
            return
        }
        layerManager.handle(event: .didSelectMarker(marker, selected), for: currentLayer?.token)

        // leaving this table here until it is depicted in unit/integration tests;
        // both `handleSelectionEvent` and `handleMarkerSelection` cover next transitions,
        // where M stands for Marker, C stands for Cluster, -> represents selection, and * represents start/end (deselect) of flow,
        // while each step can be instantiated by either MapLayer (programmatically) or MKMapView (user interaction):
        //
        // * -> M1 -> *
        // * -> M1 -> M2 -> *
        // * -> M1 -> M2: C1 -> *
        // * -> M1: C1 -> *
        // * -> M1: C1 -> M2 -> *
        // * -> M1: C1 -> M2: C1 -> *
        // * -> M1: C1 -> M2: C2 -> *
        //
        // tl;dr: these are transitions for selecting/deselecting markers of same or different clusters, or without clusters at all.

        if selected {
            // if marker selection was triggered by MKMapView, we need to update `currentLayer` selection manually,
            // as once MapLayer will receive this update it won't trigger it back here to not cause cyclic updates,
            // and it's crucial for us to keep state in sync with the MKMapView.
            currentLayer?.markerSelection = .selected(marker)
            // we don't need to re-cluster marker's group here because it would be redundant by several reasons:
            // - if MKMapView has triggered this event, it means that marker isn't clustered already, thus no need to redo it;
            // - if MapLayer has triggered this event, it's already handled in the `handleMarkerSelection`;
        } else if currentLayer?.markerSelection?.value == .none, let clusteringIdentifier = marker.clusteringIdentifier {
            // if current layer has empty marker selection, it means that it was triggered by the map layer but not the MKMapView,
            // since layer is saved before applying marker selection (see `applyState` for more details),
            // which means that we need to re-cluster its group and see if it belongs to the cluster or can be rendered separately.
            currentLayer?.clusterManagers[clusteringIdentifier]?.cluster()
        } else if marker == currentLayer?.markerSelection?.value {
            // if current layer's selection matches the marker we're deselecting here,
            // it means that it was initiated by the MKMapView and not the map layer,
            // since layer is saved before applying marker selection (see `applyState` for more details),
            // which means that we need to re-cluster its group and see if it belongs to the cluster or can be rendered separately.
            if let clusteringIdentifier = marker.clusteringIdentifier {
                currentLayer?.clusterManagers[clusteringIdentifier]?.cluster()
            }
            // if marker deselection was triggered by MKMapView, we need to update `currentLayer` selection manually,
            // as once MapLayer will receive this update it won't trigger it back here to not cause cyclic updates,
            // and it's crucial for us to keep state in sync with the MKMapView.
            currentLayer?.markerSelection = .none
        } else if marker.clusteringIdentifier != currentLayer?.markerSelection?.value.clusteringIdentifier {
            // in case it's an intermediate step when re-selecting one marker to another,
            // we need to take care of the deselecting marker cluster group,
            // and see if it belongs to the cluster or can be rendered separately.
            if let clusteringIdentifier = marker.clusteringIdentifier {
                currentLayer?.clusterManagers[clusteringIdentifier]?.cluster()
            }
        }
    }

    // MARK: UIGestureRecognizerDelegate

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - Helpers

/// Its main purpose is to prevent `AppleMapsMarkerAnnotationView` from deselecting when tapping on disabled annotation views.
/// Disabled (`isEnabled = false`) annotation views currently are `AppleMapsClusterAnnotationView` and user location annotation view.
/// However it still allows touches to be handled by the controller with its gesture recognizer (see `AppleMapsViewController.onMapDidTap`).
final class AppleMapsView: MKMapView {
    private var allowsTapGesture: Bool = true

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return allowsTapGesture
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if let annotationView = view as? MKAnnotationView {
            allowsTapGesture = annotationView.isEnabled
        } else {
            allowsTapGesture = true
        }
        return view
    }
}

private extension MKUserTrackingMode {
    var isTrackingUser: Bool {
        switch self {
        case .follow, .followWithHeading: return true
        case .none: return false
        @unknown default: return false
        }
    }
}

private extension MapRoutePlan.TransportType {
    var directionsTransportType: MKDirectionsTransportType {
        switch self {
        case .walking: return .walking
        case .publicTransport: return .transit
        case .driving: return .automobile
        case .any: return .any
        }
    }
}

private extension MKDirections {
    convenience init(plannedRoute: MapRoutePlan) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: plannedRoute.source, addressDictionary: nil))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: plannedRoute.destination, addressDictionary: nil))
        request.transportType = MKDirectionsTransportType(plannedRoute.transportType.map(\.directionsTransportType))

        self.init(request: request)
    }
}

private extension MKDirectionsTransportType {
    var transportTypes: Set<MapRoutePlan.TransportType> {
        var result: Set<MapRoutePlan.TransportType> = []
        if contains(.walking) { result.insert(.walking) }
        if contains(.transit) { result.insert(.publicTransport) }
        if contains(.automobile) { result.insert(.driving) }
        if contains(.any) { result.insert(.any) }
        return result
    }
}

private extension MapRoutePlan.Response {
    init(route: MKRoute) {
        self.init(
            coordinates: route.polyline.coordinates,
            steps: route.steps.map { step in
                MapRoutePlan.Step(coordinates: step.polyline.coordinates, transportType: step.transportType.transportTypes)
            }
        )
    }
}

private extension MKMultiPoint {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: pointCount
        )
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
