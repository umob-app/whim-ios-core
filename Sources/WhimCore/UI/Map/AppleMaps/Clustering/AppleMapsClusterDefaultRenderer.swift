import MapKit

/// Default cluster renderer which shows clusters as markers with specialized icons.
/// There is logic to decide whether to expand a cluster or not depending on the number of items or the zoom level.
///
/// [Inspiration Source](https://github.com/googlemaps/google-maps-ios-utils/blob/master/src/Clustering/View/GMUDefaultClusterRenderer.h)
public final class AppleMapsClusterDefaultRenderer: MapClusterRenderer {
    public let identifier: MapClusteringIdentifier
    public let layerToken: MapLayerToken

    private let mapView: MKMapView
    /// Previous zoom level at the moment
    private var previousZoomLevel: Double
    /// All clusters untouched that were given to be rendered.
    private var allClusters: Set<MapCluster>
    /// Clusters that weren't expanded into markers and were kept solid while rendering.
    private var renderedClusters: Set<MapCluster>
    /// Items that are rendered as a result of expanding clusters.
    private var renderedItems: Set<MapClusterItem>

    private var _clusterMarkerProvider: MapClusterMarkerProvider
    public var clusterMarkerProvider: MapClusterMarkerProvider? {
        get { _clusterMarkerProvider }
        set {
            let shouldRefresh = _clusterMarkerProvider != newValue
            _clusterMarkerProvider = newValue ?? Self.defaultClusterMarkersProvider
            if shouldRefresh {
                refresh()
            }
        }
    }

    public var clusterConfigsProvider: MapClusterConfigsProvider? {
        didSet {
            if clusterConfigsProvider != oldValue {
                refresh()
            }
        }
    }

    public init(
        identifier: MapClusteringIdentifier,
        layerToken: MapLayerToken,
        clusterMarkerProvider: MapClusterMarkerProvider?,
        clusterConfigsProvider: MapClusterConfigsProvider?,
        mapView: MKMapView
    ) {
        self.identifier = identifier
        self.layerToken = layerToken
        self.mapView = mapView
        self.previousZoomLevel = mapView.zoomLevel
        self.allClusters = []
        self.renderedClusters = []
        self.renderedItems = []
        self._clusterMarkerProvider = clusterMarkerProvider ?? Self.defaultClusterMarkersProvider
        self.clusterConfigsProvider = clusterConfigsProvider
    }

    public func render(clusters: Set<MapCluster>) {
        render(clusters: clusters, force: false)
    }

    public func refresh() {
        render(clusters: allClusters, force: true)
    }

    private func render(clusters: Set<MapCluster>, force: Bool) {
        // don't bother if nothing changed, unless it's a forced render
        guard allClusters != clusters || force else {
            return
        }
        let zoomLevel = mapView.zoomLevel
        var newClusters: Set<MapCluster> = []
        var newItems: Set<MapClusterItem> = []
        // re-assigning rendered clusters and items with new ones upon return
        defer {
            allClusters = clusters
            renderedClusters = newClusters
            renderedItems = newItems
            previousZoomLevel = zoomLevel
        }
        // if given clusters are empty, just remove old ones without extra diffing
        guard !clusters.isEmpty else {
            return mapView.removeAnnotations(mapView.annotations.filter { annotation in
                return (annotation as? AppleMapsClusterAnnotation).map(isManagedByThisRenderer)
                    ?? (annotation as? AppleMapsMarkerAnnotation).map(isManagedByThisRenderer)
                    ?? false
            })
        }
        // splitting solid clusters, and clusters to expand into markers when rendering, based on zoom level and cluster size
        let isZoomingIn = zoomLevel > previousZoomLevel
        let configs = clusterConfigsProvider?(identifier) ?? MapClusterConfigs()
        for cluster in clusters {
            if shouldRenderAsCluster(cluster, with: configs, at: zoomLevel) {
                newClusters.insert(cluster)
            } else {
                newItems.formUnion(cluster.items)
            }
        }
        // diffing stale clusters and markers that will be removed
        let clustersToRemove = renderedClusters.subtracting(newClusters)
        let itemsToRemove = renderedItems.subtracting(newItems)
        // diffing new cluster and markers that will be added
        let clustersToAdd = newClusters.subtracting(renderedClusters)
        let itemsToAdd = newItems.subtracting(renderedItems)
        // removing stale markers and clusters (immediately or animated),
        // but we need to make sure that we don't remove markers or clusters for the other cluster identifier or map layer token
        if let animationDuration = configs.animationDuration, !isZoomingIn {
            // if we're zooming out, remove only items markers and animate clusters merging
            mapView.removeAnnotations(mapView.annotations.filter { annotation in
                if let annotation = annotation as? AppleMapsMarkerAnnotation {
                    return isManagedByThisRenderer(markerAnnotation: annotation) && itemsToRemove.contains(annotation.data)
                }
                return false
            })
            zoomOut(to: clustersToAdd, from: clustersToRemove, animatedWithDuration: animationDuration)
        } else {
            // if no need to animate merging of clusters while zooming out, remove both items and clusters markers simultaneously
            mapView.removeAnnotations(mapView.annotations.filter { annotation in
                if let annotation = annotation as? AppleMapsMarkerAnnotation {
                    return isManagedByThisRenderer(markerAnnotation: annotation) && itemsToRemove.contains(annotation.data)
                } else if let annotation = annotation as? AppleMapsClusterAnnotation {
                    return isManagedByThisRenderer(clusterAnnotation: annotation) && clustersToRemove.contains(annotation.data.cluster)
                }
                return false
            })
        }
        // adding new markers and cluster (immediately or animated)
        // first, add items markers from expanded clusters
        mapView.addAnnotations(itemsToAdd.map { item in
            AppleMapsMarkerAnnotation(marker: item, layerToken: layerToken)
        })
        // second, add clusters with animating during zooming in
        if let animationDuration = configs.animationDuration, isZoomingIn {
            zoomIn(to: clustersToAdd, from: clustersToRemove, animatedWithDuration: animationDuration)
        } else {
            mapView.addAnnotations(clustersToAdd.map { cluster in
                AppleMapsClusterAnnotation(marker: _clusterMarkerProvider(cluster), layerToken: layerToken)
            })
        }
    }

    /// Heuristically finding candidate cluster to animate from, when bigger clusters break into smaller clusters.
    private func zoomIn(
        to clustersToAdd: Set<MapCluster>,
        from clustersToRemove: Set<MapCluster>,
        animatedWithDuration animationDuration: Double
    ) {
        // building lookup map from cluster item to an old cluster
        let oldItemToClustersMap = clustersToRemove.reduce(into: [MapClusterItem: MapCluster]()) { acc, cluster in
            cluster.items.forEach { acc[$0] = cluster }
        }
        // going through each cluster to be added and adding a marker for it
        for cluster in clustersToAdd {
            let annotation = AppleMapsClusterAnnotation(marker: _clusterMarkerProvider(cluster), layerToken: layerToken)
            // find a candidate cluster to animate from
            for item in cluster.items {
                // if found, immediately set initial coordinate of the cluster that we're animating from
                // and after that animate to the correct cluster coordinate
                if let fromClusterCoordinate = oldItemToClustersMap[item]?.coordinate {
                    annotation.data.coordinate.accept(CustomAnimatable(fromClusterCoordinate))
                    annotation.data.coordinate.accept(CustomAnimatable(cluster.coordinate, duration: animationDuration))
                    break
                }
            }
            // once marker is added, it will run the animation if needed, otherwise will immediately render it on the map
            mapView.addAnnotation(annotation)
        }
    }

    /// Heuristically finding candidate cluster to animate to, when smaller clusters merge into bigger clusters.
    private func zoomOut(
        to clustersToAdd: Set<MapCluster>,
        from clustersToRemove: Set<MapCluster>,
        animatedWithDuration animationDuration: Double
    ) {
        // building lookup map from cluster item to a new cluster
        let newItemToClustersMap = clustersToAdd.reduce(into: [MapClusterItem: MapCluster]()) { acc, cluster in
            cluster.items.forEach { acc[$0] = cluster }
        }
        // building lookup map from stale clusters, to their map annotations that should be removed from the map
        let clusterAnnotationsToRemove = mapView.annotations.reduce(into: [MapCluster: AppleMapsClusterAnnotation]()) { acc, annotation in
            guard let annotation = annotation as? AppleMapsClusterAnnotation else {
                return
            }
            if isManagedByThisRenderer(clusterAnnotation: annotation) && clustersToRemove.contains(annotation.data.cluster) {
                acc[annotation.data.cluster] = annotation
            }
        }
        // going through each cluster to be removed and adding a marker for it
        for cluster in clustersToRemove {
            guard let annotation = clusterAnnotationsToRemove[cluster] else {
                continue
            }
            var removeAfterAnimation = false
            // find a candidate cluster to animate to
            for item in cluster.items {
                // if found, animate coordinate of the cluster to the one that is "merging" with
                if let toCluster = newItemToClustersMap[item] {
                    annotation.data.coordinate.accept(CustomAnimatable(toCluster.coordinate, duration: animationDuration))
                    removeAfterAnimation = true
                    break
                }
            }
            // if cluster is animated, remove it approximately afterwards, otherwise - immediately
            if removeAfterAnimation {
                DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) { [weak self] in
                    self?.mapView.removeAnnotation(annotation)
                }
            } else {
                mapView.removeAnnotation(annotation)
            }
        }
    }

    private func isManagedByThisRenderer(clusterAnnotation: AppleMapsClusterAnnotation) -> Bool {
        return clusterAnnotation.layerToken == layerToken && clusterAnnotation.data.cluster.identifier == identifier
    }

    private func isManagedByThisRenderer(markerAnnotation: AppleMapsMarkerAnnotation) -> Bool {
        return markerAnnotation.layerToken == layerToken && markerAnnotation.data.clusteringIdentifier == identifier
    }

    private func shouldRenderAsCluster(_ cluster: MapCluster, with configs: MapClusterConfigs, at zoomLevel: Double) -> Bool {
        return cluster.items.count >= configs.minimumClusterSize && zoomLevel < configs.maximumClusterZoom
    }
}

extension AppleMapsClusterDefaultRenderer {
    static let defaultClusterMarkersProvider = MapClusterMarkerProvider { cluster in
        MapClusterMarker(
            cluster: cluster,
            icon: .image(CustomAnimatable(ClusterMarkerView.makeImage(count: cluster.items.count)))
        )
    }
}

// MARK: - Default Icon Generator

private final class ClusterMarkerView: UIView {
    struct Props: Hashable {
        let color: UIColor, value: String

        init(count: Int) {
            color = ClusterMarkerView.color(for: count)
            value = ClusterMarkerView.text(for: count)
        }
    }

    private static var cache: [Props: UIImage] = [:]

    static func makeImage(count: Int) -> UIImage {
        if let image = cache[Props(count: count)] {
            return image
        }
        let view = ClusterMarkerView(count: count)
        let image = view.asImage()
        cache[view.props] = image
        return image
    }

    let props: Props

    private init(count: Int) {
        self.props = Props(count: count)

        let size = Self.size(for: count)
        let padding: CGFloat = 3

        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))

        let label = UILabel(frame: CGRect(x: padding, y: 0, width: size - padding, height: size))
        label.textColor = .white
        label.text = props.value
        label.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        label.minimumScaleFactor = 0.3
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = .center
        addSubview(label)
        layer.cornerRadius = size / 2
        backgroundColor = props.color
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func text(for count: Int) -> String {
        switch count {
        case 1000...: return "1000+"
        case 500...: return "500+"
        case 200...: return "200+"
        case 100...: return "100+"
        case 50...: return "50+"
        case 20...: return "20+"
        case 10...: return "10+"
        case 5...: return "5+"
        default: return "\(count)"
        }
    }

    private static func color(for count: Int) -> UIColor {
        switch count {
        case 1000...: return .red
        case 200...: return .brown
        default: return .gray
        }
    }

    private static func size(for count: Int) -> CGFloat {
        switch count {
        case 1000...: return 62
        case 100...: return 52
        case 10...: return 42
        default: return 32
        }
    }

    private func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}
