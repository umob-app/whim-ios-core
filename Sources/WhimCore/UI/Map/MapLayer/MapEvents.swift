import Foundation
import CoreLocation

// sourcery: Random
/// Events emitted by map view.
public enum MapEvent: Equatable {
    // sourcery: Random
    public enum ChangingPositionStatus: Equatable, CaseIterable {
        case starting, inProgress, ended
    }
    /// Fired when user interacts with the map or when map's region is changed programmatically.
    ///
    /// Corresponds to `MKMapViewDelegate`
    /// - `mapView(_:, regionWillChangeAnimated:)`
    /// - `mapView(_:, regionDidChangeAnimated:)`
    case changingPosition(status: ChangingPositionStatus, center: CLLocationCoordinate2D, zoom: Double, heading: CLLocationDirection, span: MapCoordinateSpan)

    /// Fired when visible rect inset is calculated automatically by the map depending on the bottom and top views overlapping it.
    /// Should not be fired if layer has `custom` visible rect inset value.
    case didUpdateVisibleRectInset(MapLayerVisibleRectInset)
    case didUpdateUserTracking(Bool)
    case didTapSidebarItem(MapSidebarItem)
    /// Will emit if tap didn't hit any marker or overlay.
    case didTap(CLLocationCoordinate2D)

    /// Notifies of selection or deselection of the markers that are managed by the map.
    /// If selected, value will be `true`, if deselected - `false`.
    case didSelectMarker(MapMarker, Bool)
    /// Basically the same if you subscribe to `MapClusterMarker.events`, no difference. Choose whichever suits you best.
    case didTapOnCluster(MapClusterMarker)
    /// Basically the same if you subscribe to `MapOverlay.events`, no difference. Choose whichever suits you best.
    case didTapInsideOverlay(MapOverlay, CLLocationCoordinate2D)

    /// Notifies of planned routes calculating progress.
    case didStartCalculatingRoutes([MapRoutePlan])
    case didFinishCalculatingRoutes([MapRoutePlan: Result<MapRoutePlan.Response, NSError>])
}

// sourcery: Random
/// Events emitted both by map view and layer.
public enum MapLayerEvent: Equatable {
    case map(MapEvent)
    case didBecomeActive(Bool)
}

// MARK: - Extensions

public extension MapEvent {
    var changingPosition: (status: ChangingPositionStatus, center: CLLocationCoordinate2D, zoom: Double, heading: CLLocationDirection, span: MapCoordinateSpan)? {
        guard case let .changingPosition(status, center, zoom, heading, span) = self else { return nil }
        return (status, center, zoom, heading, span)
    }
    var didUpdateVisibleRectInset: MapLayerVisibleRectInset? {
        guard case let .didUpdateVisibleRectInset(inset) = self else { return nil }
        return inset
    }
    var didUpdateUserTracking: Bool? {
        guard case let .didUpdateUserTracking(userTracking) = self else { return nil }
        return userTracking
    }
    var didTapSidebarItem: MapSidebarItem? {
        guard case let .didTapSidebarItem(item) = self else { return nil }
        return item
    }
    var didTap: CLLocationCoordinate2D? {
        guard case let .didTap(coordinate) = self else { return nil }
        return coordinate
    }
    var didSelectMarker: (marker: MapMarker, isSelected: Bool)? {
        guard case let .didSelectMarker(marker, isSelected) = self else { return nil }
        return (marker, isSelected)
    }
    var selectedMarker: MapMarker? {
        guard case let .didSelectMarker(marker, true) = self else { return nil }
        return marker
    }
    var deselectedMarker: MapMarker? {
        guard case let .didSelectMarker(marker, false) = self else { return nil }
        return marker
    }
    var didTapOnCluster: MapClusterMarker? {
        guard case let .didTapOnCluster(marker) = self else { return nil }
        return marker
    }
    var didTapInsideOverlay: (overlay: MapOverlay, coordinate: CLLocationCoordinate2D)? {
        guard case let .didTapInsideOverlay(overlay, coordinate) = self else { return nil }
        return (overlay, coordinate)
    }
    var didTapAnywhere: CLLocationCoordinate2D? {
        return didTap ?? didTapInsideOverlay?.coordinate
    }
    var didStartCalculatingRoutes: [MapRoutePlan]? {
        guard case let .didStartCalculatingRoutes(routes) = self else { return nil }
        return routes
    }
    var didFinishCalculatingRoutes: [MapRoutePlan: Result<MapRoutePlan.Response, NSError>]? {
        guard case let .didFinishCalculatingRoutes(routes) = self else { return nil }
        return routes
    }
}

public extension MapEvent.ChangingPositionStatus {
    var isStarting: Bool {
        guard case .starting = self else { return false }
        return true
    }
    var isInProgress: Bool {
        guard case .inProgress = self else { return false }
        return true
    }
    var isEnded: Bool {
        guard case .ended = self else { return false }
        return true
    }
}

public extension MapLayerEvent {
    var map: MapEvent? {
        guard case let .map(map) = self else { return nil }
        return map
    }
}
