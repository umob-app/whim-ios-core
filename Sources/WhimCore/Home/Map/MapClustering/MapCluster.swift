import CoreLocation
import RxRelay

// MARK: - Clustering Identifier

/// Unique identifier that allows distinguishing between different cluster groups.
public typealias MapClusteringIdentifier = String

// MARK: - Cluster Item

/// An item which is grouped into cluster.
public typealias MapClusterItem = MapMarker

// MARK: - Cluster

/// Defines a generic cluster object.
///
/// - Important: It shouldn't containt any reference semantics behavior. It should be treated as a value type.
///
/// [Inspiration Source](https://github.com/googlemaps/google-maps-ios-utils/blob/master/src/Clustering/GMUCluster.h)
public class MapCluster {
    public let identifier: MapClusteringIdentifier
    public let coordinate: CLLocationCoordinate2D
    public fileprivate(set) var items: Set<MapClusterItem>

    fileprivate init(identifier: MapClusteringIdentifier, coordinate: CLLocationCoordinate2D, items: Set<MapClusterItem>) {
        self.identifier = identifier
        self.items = items
        self.coordinate = coordinate
    }

    /// Creates a cluster whose coordinate is calculated as a mid point among all items.
    public static func makeDefault(identifier: MapClusteringIdentifier, items: Set<MapClusterItem>) -> MapCluster {
        let count = Double(items.count)
        let sumCoordinate = items.reduce(into: CLLocationCoordinate2D()) { acc, item in
            acc.latitude += item.position.latitude
            acc.longitude += item.position.longitude
        }
        return MapCluster(
            identifier: identifier,
            coordinate: CLLocationCoordinate2D(latitude: sumCoordinate.latitude / count, longitude: sumCoordinate.longitude / count),
            items: items
        )
    }

    /// Creates a cluster whose coordinate is fixed upon construction.
    public static func makeStatic(identifier: MapClusteringIdentifier, coordinate: CLLocationCoordinate2D, items: Set<MapClusterItem> = []) -> MutableMapCluster {
        return MutableMapCluster(identifier: identifier, coordinate: coordinate, items: items)
    }
}

// MARK: - Mutable Cluster

/// Represents a cluster which can add and remove items.
public final class MutableMapCluster: MapCluster {
    public func add(item: MapClusterItem) {
        items.insert(item)
    }

    public func remove(item: MapClusterItem) {
        items.remove(item)
    }
}

// MARK: - Extensions

extension MapCluster: Equatable, Hashable {
    public static func == (lhs: MapCluster, rhs: MapCluster) -> Bool {
        return lhs.identifier == rhs.identifier
            && lhs.coordinate == rhs.coordinate
            && lhs.items == rhs.items
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(coordinate)
        hasher.combine(items)
    }
}
