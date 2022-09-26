import MapKit

/// A simple clustering algorithm with O(nlog n) performance. Resulting clusters are not hierarchical.
///
/// High level algorithm:
/// 1. Iterate over items in the order they were added (candidate clusters).
/// 2. Create a cluster with the center of the item.
/// 3. Add all items that are within a certain distance to the cluster.
/// 4. Move any items out of an existing cluster if they are closer to another cluster.
/// 5. Remove those items from the list of candidate clusters.
///
/// Clusters have the center of the first element (not the centroid of the items within it).
///
/// [Inspiration Source](https://github.com/googlemaps/google-maps-ios-utils/blob/master/src/Clustering/Algo/GMUNonHierarchicalDistanceBasedAlgorithm.h)
public final class AppleMapsClusterNonHierarchicalDistanceBasedAlgorithm: MapClusterAlgorithm {
    public let identifier: MapClusteringIdentifier

    private let mapView: MKMapView

    private var sortedItems: [MapClusterItem] = []
    public private(set) var items: Set<MapClusterItem> = [] {
        didSet {
            guard oldValue != items else {
                return
            }
            // sorting items to keep consistency during reclustering so that we always render same clusters for same set of items;
            // to be fair, this is a bit hacky way to achieve this goal,
            // more "correct" way would be to pass items in array or ordered set, but it would make it harder to diff between them;
            // until we have good and easy-to-use diffing algorithm, using sets and sorting items here seems to be lesser evil.
            sortedItems = items.sorted(by: { lhs, rhs in
                let lhs = lhs.coordinate.value.value
                let rhs = rhs.coordinate.value.value
                return lhs.longitude != rhs.longitude
                    ? lhs.longitude < rhs.longitude
                    : lhs.latitude < rhs.latitude
            })
        }
    }
    private let quadTree: MapQuadTree

    private let clusterDistancePoints = 70.0

    public init(identifier: MapClusteringIdentifier, mapView: MKMapView, items: Set<MapClusterItem> = []) {
        self.identifier = identifier
        self.mapView = mapView
        self.quadTree = MapQuadTree(items: Array(items))
        // triggering `items` didSet handler from initializer
        ({ self.items = items })()
    }

    public func replaceItems(with items: Set<MapClusterItem>) {
        guard self.items != items else {
            return
        }
        let toAdd = items.subtracting(self.items)
        let toRemove = self.items.subtracting(items)

        self.items = items
        toRemove.forEach { quadTree.remove($0) }
        toAdd.forEach { quadTree.add($0) }
    }

    public func clearItems() {
        items = []
        quadTree.clear()
    }

    public func clusters(at zoomLevel: Double, except: MapClusterItem? = nil) -> Set<MapCluster> {
        var clusters: Set<MapCluster> = []
        var itemToClusterMap: [MapClusterItem: MutableMapCluster] = [:]
        var itemToClusterDistanceMap: [MapClusterItem: Double] = [:]
        var processedItems: Set<MapClusterItem> = []
        // note that this method returns zero latitude span to let MapKit calculate it, so we rely only on longitude span here
        let radius = mapView.coordinateSpan(
            zoomLevel: zoomLevel,
            rotation: mapView.camera.heading,
            mapSize: CGSize(width: clusterDistancePoints * 2, height: clusterDistancePoints * 2),
            edgeInset: .zero
        ).longitudeDelta
        // splitting radius for latitude in half to have a square area,
        // because otherwise it'd be a rectangle due to (web) mercator projection: map is 180° w-e and 90(actually ~85.05)° n-s
        let areaSpan = MKCoordinateSpan(latitudeDelta: radius / 2, longitudeDelta: radius)

        for item in sortedItems {
            guard !item.isSelected.value && except != item else {
                // selected item should not be clustered with others, thus we put it into a separate singleton cluster;
                // then it's up to a renderer how to view it, most likely it'll be shown as item, not as a single-item cluster;
                // this way we're doing our best to keep selected item on the map.
                clusters.insert(MapCluster.makeStatic(identifier: identifier, coordinate: item.position, items: [item]))
                continue
            }
            guard !processedItems.contains(item) else {
                continue
            }
            let cluster = MapCluster.makeStatic(identifier: identifier, coordinate: item.position)

            // Query for items within a fixed point distance from the current item to make up a cluster around it.
            let areaAroundPoint = MKMapRect(center: item.position, span: areaSpan)
            let point = areaAroundPoint.midPoint
            let nearbyItems = quadTree.items(in: areaAroundPoint)

            for quadItem in nearbyItems {
                let nearbyItem = quadItem
                processedItems.insert(nearbyItem)
                let nearbyItemPoint = MKMapPoint(nearbyItem.position)
                let key = nearbyItem

                let existingDistance = itemToClusterDistanceMap[key]
                let squaredDistance = distanceSquared(between: point, and: nearbyItemPoint)

                if let existingDistance = existingDistance {
                    guard existingDistance >= squaredDistance else {
                        // Already belongs to a closer cluster.
                        continue
                    }
                    let existingCluster = itemToClusterMap[key]
                    existingCluster?.remove(item: nearbyItem)
                }
                itemToClusterDistanceMap[key] = squaredDistance
                itemToClusterMap[key] = cluster
                cluster.add(item: nearbyItem)
            }
            clusters.insert(cluster)
        }
        return clusters
    }
}

private func distanceSquared(between a: MKMapPoint, and b: MKMapPoint) -> Double {
    let deltaX = a.x - b.x
    let deltaY = a.y - b.y
    return deltaX * deltaX + deltaY * deltaY
}

private extension MKMapRect {
    init(center: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        let minPoint = MKMapPoint(CLLocationCoordinate2D(
            latitude: center.latitude + span.latitudeDelta,
            longitude: center.longitude - span.longitudeDelta
        ))
        let maxPoint = MKMapPoint(CLLocationCoordinate2D(
            latitude: center.latitude - span.latitudeDelta,
            longitude: center.longitude + span.longitudeDelta
        ))
        self.init(minX: minPoint.x, minY: minPoint.y, maxX: maxPoint.x, maxY: maxPoint.y)
    }

    var midPoint: MKMapPoint {
        return MKMapPoint(x: midX, y: midY)
    }
}
