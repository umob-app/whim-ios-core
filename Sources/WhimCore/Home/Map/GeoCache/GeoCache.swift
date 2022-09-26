import CoreLocation
import MapKit

// MARK: - Values

/// Accuracy mode used when searching data and calculating coverage index in the given area.
public enum GeoCacheAccuracy {
    case approximate, precise
}

/// Item with its coordinate.
public struct GeoCacheItem<T: Hashable>: Hashable {
    public let value: T
    public let coordinate: CLLocationCoordinate2D

    public init(value: T, coordinate: CLLocationCoordinate2D) {
        self.value = value
        self.coordinate = coordinate
    }
}

// MARK: - Protocols

public protocol ReadOnlyGeoCache {
    associatedtype Value: Hashable

    typealias Item = GeoCacheItem<Value>

    func search(inRegion region: AreaRegion, accuracy: GeoCacheAccuracy) -> (items: Set<Item>, coverage: Float)
    func hasCoverage(of requested: Float, inRegion region: AreaRegion) -> Bool
}

public protocol ReadWriteGeoCache: ReadOnlyGeoCache {
    func insert(item: Item) -> Bool
    func insert<Items>(items newItems: Items, inRegion region: AreaRegion) where Items: Collection, Items.Element == Item
}

// MARK: - GeoCache

/// In-memory cache based on proximity geohashing.
///
/// Stores items in geohash blocks of given precision, and allows fast data retrieval in requested area.
/// It can also provide info about data coverage index inside requested area.
public final class GeoCache<T: Hashable>: ReadWriteGeoCache {
    public typealias Value = T

    /// Area coverage by the items insereted into the cache.
    /// - `partial` means that geohash bounding-box doesn't fully cover the requested area
    /// - `full` means that geohash bounding-box was fully included in the area when inserting new items to the cache.
    private enum Coverage: Equatable {
        case full, partial
    }

    private let lock: NSRecursiveLock
    private let precision: Int
    private var coverage: [GeoHash.Code: Coverage]
    private var items: [GeoHash.Code: Set<Item>]

    /// Creates cache with data stored in blocks of given precision.
    /// Geohash blocks will not be divided into smaller ones no matter how much data they have.
    /// Please choose precision with care. The bigger the precision, the more calculations are required to maintain it, much more.
    /// However the less the prevcision is, the less accuracy you get.
    /// 6 or 7 looks like a good balance to me for common use-cases.
    public init(precision: Int = 6) {
        self.lock = NSRecursiveLock()
        self.items = [:]
        self.coverage = [:]
        self.precision = precision
    }

    /// Inserts the given item in the cache if it is not already present.
    /// If the area where this item belongs isn't covered yet (see `add(items:)`), it will receive `partial` coverage.
    /// - Returns: boolean flag stating whether an item was inserted.
    @discardableResult
    public func insert(item: Item) -> Bool {
        lock.lock(); defer { lock.unlock() }

        let geohash = GeoHash.encode(coordinate: item.coordinate, length: precision)
        let inserted = items[geohash, default: []].insert(item).inserted

        if inserted, coverage[geohash] == nil {
            coverage[geohash] = .partial
        }
        return inserted
    }

    /// Inserts the given items in the cache if they are not already present.
    /// Geohash boxes, whose area is fully bounded by the given region (center & radius) will receive `full` coverage.
    /// Geohash boxes, whose area intersects the given region, will receive `partial` coverage.
    /// Hence make sure to keep given region with the items you provide in sync.
    public func insert<Items>(items newItems: Items, inRegion region: AreaRegion) where Items: Collection, Items.Element == Item {
        lock.lock(); defer { lock.unlock() }

        let geohashes = ProximityHash.geohashes(
            inRegion: region,
            ofLength: precision,
            includingIntersecting: true
        )
        for (geohash, bounds) in geohashes {
            switch bounds {
            case .included:
                coverage[geohash] = .full
            case .intersecting:
                if coverage[geohash] != .full {
                    coverage[geohash] = .partial
                }
            }
        }
        for item in newItems {
            let geohash = GeoHash.encode(coordinate: item.coordinate, length: precision)
            if coverage[geohash] != .full {
                coverage[geohash] = .partial
            }
            items[geohash, default: []].insert(item)
        }
    }

    /// Search items in requested region area (circular or rectangular), and provide area coverage index.
    ///
    /// - If given `precise` accuracy, only items that are strictly included in the area bounds will be returned;
    /// - If given `approximate` accuracy, all items from geohash boxes will be returned without additional filtering;
    ///
    /// When calculating coverage index, we treat fully included geohash boxes as `1` unit and partially included as `0.5`,
    /// which is not 100% correct but brings us closer to needed result the higher `precision` level we have.
    public func search(inRegion region: AreaRegion, accuracy: GeoCacheAccuracy) -> (items: Set<Item>, coverage: Float) {
        lock.lock(); defer { lock.unlock() }

        let geohashes = ProximityHash.geohashes(
            inRegion: region,
            ofLength: precision,
            includingIntersecting: true
        )
        let result = geohashes.reduce(into: (items: Set<Item>(), covered: Float())) { acc, boundedGeohash in
            if let itemsPerGeohash = items[boundedGeohash.key] {
                switch accuracy {
                case .approximate:
                    acc.items.formUnion(itemsPerGeohash)
                case .precise:
                    let itemsPreciselyInRegion = itemsPerGeohash.filter { region.contains($0.coordinate) }
                    acc.items.formUnion(Set(itemsPreciselyInRegion))
                }
            }
            acc.covered += coverageIndex(for: boundedGeohash.key)
        }
        return (result.items, result.covered / Float(geohashes.count))
    }

    /// Returns true if given region has requested precision.
    /// This method is more encouraged to be used if you only need to know whether coverage level is satisfying,
    /// as it performs less computations.
    public func hasCoverage(of requested: Float, inRegion region: AreaRegion) -> Bool {
        lock.lock(); defer { lock.unlock() }

        let geohashes = ProximityHash.geohashes(
            inRegion: region,
            ofLength: precision,
            includingIntersecting: true
        )
        let total = Float(geohashes.count)
        var covered = Float()
        for geohash in geohashes.keys {
            covered += coverageIndex(for: geohash)
            if (covered / total) >= requested {
                return true
            }
        }
        return false
    }

    private func coverageIndex(for geohash: GeoHash.Code) -> Float {
        switch coverage[geohash] {
        case .full: return 1
        case .partial: return 0.5
        case .none: return 0
        }
    }
}

// MARK: - Extensions

public extension ReadWriteGeoCache {
    func insert<Items>(
        items newItems: Items,
        aroundCoordinate center: CLLocationCoordinate2D,
        inRadius radius: CLLocationDistance
    ) where Items: Collection, Items.Element == Item {
        insert(items: newItems, inRegion: .circular(.init(center: center, radius: radius)))
    }
}

public extension ReadOnlyGeoCache {
    func search(inRegion region: AreaRegion) -> (items: Set<Item>, coverage: Float) {
        search(inRegion: region, accuracy: .approximate)
    }

    func search(
        aroundCoordinate center: CLLocationCoordinate2D,
        inRadius radius: CLLocationDistance,
        accuracy: GeoCacheAccuracy = .approximate
    ) -> (items: Set<Item>, coverage: Float) {
        search(inRegion: .circular(.init(center: center, radius: radius)), accuracy: accuracy)
    }

    func search(inRect rect: MKCoordinateRegion, accuracy: GeoCacheAccuracy = .approximate) -> (items: Set<Item>, coverage: Float) {
        search(inRegion: .rectangular(.init(center: rect.center, span: rect.span)), accuracy: accuracy)
    }

    func hasCoverage(of requested: Float, aroundCoordinate center: CLLocationCoordinate2D, inRadius radius: CLLocationDistance) -> Bool {
        hasCoverage(of: requested, inRegion: .circular(.init(center: center, radius: radius)))
    }

    func hasCoverage(of requested: Float, inRect rect: MKCoordinateRegion) -> Bool {
        hasCoverage(of: requested, inRegion: .rectangular(.init(region: rect)))
    }
}
