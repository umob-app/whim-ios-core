import MapKit

/// Generic protocol for arranging cluster items into groups.
///
/// [Inspiration Source](https://github.com/googlemaps/google-maps-ios-utils/blob/master/src/Clustering/Algo/GMUClusterAlgorithm.h)
public protocol MapClusterAlgorithm: AnyObject {
    var items: Set<MapClusterItem> { get }

    /// Replaces old cluster items in the collection with the new ones.
    func replaceItems(with items: Set<MapClusterItem>)
    /// Clears all items.
    func clearItems()
    /// Returns the set of clusters of the added items.
    /// Pass exceptional item that shouldn't be clustered with others and will be placed in its own singleton cluster.
    /// If item is selected, it will be also placed in its own singleton cluster.
    func clusters(at zoomLevel: Double, except: MapClusterItem?) -> Set<MapCluster>
}

extension MapClusterAlgorithm {
    func clusters(at zoomLevel: Double) -> Set<MapCluster> {
        clusters(at: zoomLevel, except: nil)
    }
}
