import MapKit

// MARK: - Marker Provider

/// A function that provides marker for the given cluster to render it on the map.
public typealias MapClusterMarkerProvider = FunctionObject<MapCluster, MapClusterMarker>

// MARK: - Configs Provider

/// A function that provides configs for the given clusters group given the unique cluster identifier.
public typealias MapClusterConfigsProvider = FunctionObject<MapClusteringIdentifier, MapClusterConfigs>

// sourcery: Random
public struct MapClusterConfigs: Hashable {
    /// Determines the minimum number of cluster items inside a cluster.
    /// Clusters smaller than this threshold will be expanded.
    ///
    /// Defaults to `4`
    public let minimumClusterSize: Int
    /// Sets the maximium zoom level of the map on which the clustering should be applied.
    /// At zooms above this level, clusters will be expanded.
    /// This is to prevent cases where items are so close to each other than they are always grouped.
    ///
    /// Defaults to `20`
    public let maximumClusterZoom: Double
    /// Sets the animation duration for marker splitting/merging effects. Measured in seconds.
    /// No animation will be performed if value is `nil`.
    ///
    /// Defaults to `0.5`.
    public let animationDuration: TimeInterval?
    /// Animates the clusters to achieve splitting (when zooming in) and merging (when zooming out) effects:
    /// - splitting large clusters into smaller ones when zooming in.
    /// - merging small clusters into bigger ones when zooming out.
    ///
    /// - NOTE: the position to animate to/from for each cluster is heuristically calculated by finding the first overlapping cluster.
    /// This means that:
    /// - when zooming in:
    ///    if a cluster on a higher zoom level is made from multiple clusters on a lower zoom level,
    ///    the split will only animate the new cluster from one of them.
    /// - when zooming out:
    ///    if a cluster on a higher zoom level is split into multiple parts to join multiple clusters at a lower zoom level,
    ///    the merge will only animate the old cluster into one of them.
    /// Because of these limitations, the actual cluster sizes may not add up,
    /// for example people may see 3 clusters of size 3, 4, 5 joining to make up a cluster of only 8 for non-hierachical clusters.
    /// And vice versa, a cluster of 8 may split into 3 clusters of size 3, 4, 5.
    /// For hierarchical clusters, the numbers should add up however.
    ///
    /// Derived from `animationDuration` - will be `true` if duration is not `nil`, otherwise - false.
    public var animatesClusters: Bool {
        animationDuration != nil
    }

    public init(minimumClusterSize: Int = 4, maximumClusterZoom: Double = 20, animationDuration: Double? = 0.5) {
        self.minimumClusterSize = minimumClusterSize
        self.maximumClusterZoom = maximumClusterZoom
        self.animationDuration = animationDuration
    }
}

// MARK: - Renderer

/// Defines a common contract for a cluster renderer.
///
/// [Inspiration Source](https://github.com/googlemaps/google-maps-ios-utils/blob/master/src/Clustering/View/GMUClusterRenderer.h)
public protocol MapClusterRenderer: AnyObject {
    var clusterMarkerProvider: MapClusterMarkerProvider? { get set }
    var clusterConfigsProvider: MapClusterConfigsProvider? { get set }

    /// Renders a list of clusters.
    func render(clusters: Set<MapCluster>)
    /// Re-renders existing clusters on the map by re-applying given markes and configs provider.
    func refresh()
}
