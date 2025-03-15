import MapKit
import RxSwift

// MARK: - Manager

// TODO: CLUSTERING: Remove MKMapView dependency somehow ??? So that it's more generic without coupling with Apple Maps.

/// This class groups many items on a map based on zoom level.
/// Cluster items should be added to the map via this class.
///
/// [Inspiration Source](https://github.com/googlemaps/google-maps-ios-utils/blob/master/src/Clustering/GMUClusterManager.h)
public final class MapClusterManager {
    private static let clusterWaitInterval: TimeInterval = 0.2

    public let identifier: MapClusteringIdentifier
    public let algorithm: MapClusterAlgorithm
    public let renderer: MapClusterRenderer

    public var items: Set<MapClusterItem> {
        return algorithm.items
    }

    /// The map view that this object is associated with, and dispose bag for listening to its updates.
    private let mapView: MKMapView
    private let disposeBag = DisposeBag()

    /// Tracks number of cluster requests so that we can safely ignore stale (redundant) ones.
    private var clusterRequestCount: UInt64 = 0
    /// Zoom level of the map on the previous cluster invocation.
    private var previousZoomLevel: Double

    public init(identifier: MapClusteringIdentifier, mapView: MKMapView, algorithm: MapClusterAlgorithm, renderer: MapClusterRenderer) {
        self.identifier = identifier
        self.algorithm = algorithm
        self.renderer = renderer
        self.mapView = mapView
        self.previousZoomLevel = mapView.zoomLevel

        mapView.rx.zoomLevel
            .subscribe(onNext: { [weak self] zoomLevel in self?.updateZoomLevel(with: zoomLevel) })
            .disposed(by: disposeBag)
    }

    deinit {
        clearItems()
    }

    /// Replaces old cluster items in the collection with the new ones.
    public func replaceItems(with items: Set<MapClusterItem>) {
        // checking it here to not execute `cluster` for the same items
        guard algorithm.items != items else {
            return
        }
        algorithm.replaceItems(with: items)
        cluster()
    }

    /// Removes all items from the collection.
    public func clearItems() {
        algorithm.clearItems()
        cluster()
    }

    /// Called to arrange items into groups.
    /// - This method will be automatically invoked when the map's zoom level changes or when new items have been added.
    /// - Manually invoke this method to rearrange items.
    public func cluster(except: MapClusterItem? = nil) {
        let zoomLevel = mapView.zoomLevel
        let clusters = algorithm.clusters(at: zoomLevel.integral, except: except)
        renderer.render(clusters: clusters)
        previousZoomLevel = zoomLevel
    }

    private func updateZoomLevel(with zoomLevel: Double) {
        let previousIntegralZoom = previousZoomLevel.integral
        let currentIntegralZoom = zoomLevel.integral
        if previousIntegralZoom != currentIntegralZoom {
            requestCluster()
        }
    }

    private func requestCluster() {
        clusterRequestCount += 1
        let requestNumber = clusterRequestCount
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.clusterWaitInterval) { [weak self] in
            // Ignore if there are newer requests.
            guard let self = self, requestNumber == self.clusterRequestCount else {
                return
            }
            self.cluster()
        }
    }
}

// MARK: - Helpers

private extension Double {
    var integral: Double {
        return (self + 0.5).rounded(.down)
    }
}
