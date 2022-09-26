import CoreLocation

/// Geohash algorithm implementation.
///
/// It is a hierarchical spatial data structure which subdivides space into buckets of grid shape,
/// which is one of the many applications of what is known as a Z-order curve, and generally space-filling curves.
///
/// Geohashes offer properties like arbitrary precision
/// and the possibility of gradually removing characters from the end of the code to reduce its size (and gradually lose precision).
/// Geohashing guarantees that the longer a shared prefix between two geohashes is, the spatially closer they are together.
/// The reverse of this is not guaranteed, as two points can be very close but have a short or no shared prefix.
///
/// Links:
/// - [Wikipedia](https://en.wikipedia.org/wiki/Geohash)
/// - [Geohash.org](http://geohash.org)
/// - [Live Map](http://mapzen.github.io/leaflet-spatial-prefix-tree/)
/// - [JS](http://www.movable-type.co.uk/scripts/geohash.html) and [Python](https://github.com/wdm0006/pygeohash) implementations

public enum GeoHash {
    public typealias Code = String

    // bit parity, used while encoding/decoding geohash
    private enum Parity: Equatable {
        case even, odd

        mutating func toggle() {
            switch self {
            case .even: self = .odd
            case .odd: self = .even
            }
        }
    }

    // geohash-specific base32 alphabet for encoding/decoding
    private static let base32EncodeTable = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    private static let base32DecodeTable = base32EncodeTable.charAtIdxTable

    // each character in geohash-specific base32 alphabet is 5 bits long
    private static let base32CharFirstBit = 0b10000
    private static let base32CharLastBit = 0b00000

    // valid bounds of the world
    static let world = (
        lat: (min: -90.0, max: 90.0),
        lon: (min: -180.0, max: 180.0)
    )

    // minimal and maximal geohash lengths allowed
    private static let geohashLengthBounds = (min: 1, max: 22)

    // precalculated tables of neigbours for the character at respective position
    private static let neighborsEncodeTable: [Direction: [Parity: [Code.Element]]] = [
        .north: [.even: Array("p0r21436x8zb9dcf5h7kjnmqesgutwvy"), .odd: Array("bc01fg45238967deuvhjyznpkmstqrwx")],
        .south: [.even: Array("14365h7k9dcfesgujnmqp0r2twvyx8zb"), .odd: Array("238967debc01fg45kmstqrwxuvhjyznp")],
        .east:  [.even: Array("bc01fg45238967deuvhjyznpkmstqrwx"), .odd: Array("p0r21436x8zb9dcf5h7kjnmqesgutwvy")],
        .west:  [.even: Array("238967debc01fg45kmstqrwxuvhjyznp"), .odd: Array("14365h7k9dcfesgujnmqp0r2twvyx8zb")]
    ]
    private static let neighborsDecodeTable = neighborsEncodeTable.compactMapValues { neigborsPerParity in
        zip(neigborsPerParity[.even], neigborsPerParity[.odd]).map { even, odd in
            [Parity.even: even.charAtIdxTable, .odd: odd.charAtIdxTable]
        }
    }

    // precalculated tables of borders for the grid
    private static let bordersEncodeTable: [Direction: [Parity: [Code.Element]]] = [
        .north: [.even: Array("prxz"),     .odd: Array("bcfguvyz")],
        .south: [.even: Array("028b"),     .odd: Array("0145hjnp")],
        .east:  [.even: Array("bcfguvyz"), .odd: Array("prxz")],
        .west:  [.even: Array("0145hjnp"), .odd: Array("028b")]
    ]
    private static let bordersDecodeTable = bordersEncodeTable.compactMapValues { neigborsPerParity in
        zip(neigborsPerParity[.even], neigborsPerParity[.odd]).map { even, odd in
            [Parity.even: even.charAtIdxTable, .odd: odd.charAtIdxTable]
        }
    }

    /// Encodes a coordinate to a geohash string of a given length.
    ///
    /// If `length` is out of minimal and maximal bounds, it will be constrained to the closest one.
    /// - Parameters:
    ///   - coordinate: coordinate to encode.
    ///   - length: min: 1, max: 22
    /// - Returns: geohash string of a given length.
    ///
    /// Example:
    /// ```
    /// let geohash = GeoHash.encode(
    ///     coordinate: .init(latitude: 40.75798, longitude: -73.991516),
    ///     length: 12
    /// )
    /// print(geohash) // will print "dr5ru7c02wnv"
    /// ```
    public static func encode(coordinate: CLLocationCoordinate2D, length: Int) -> Code {
        memoizedGeohashesLock.lock(); defer { memoizedGeohashesLock.unlock() }
        if let geohash = memoizedGeohashes[MemoizationKey(coordinate: coordinate, length: length)] {
            return geohash
        }
        let geohash = Box(coordinate: coordinate, length: length).geohash
        memoizedGeohashes[MemoizationKey(coordinate: coordinate, length: length)] = geohash
        return geohash
    }

    // table that contains already calculated geohashes for corresponding coordinate and length;
    // it's pretty handy when used by ProximityHash, which requires many geohash calculations,
    // however it does so for their bounding-box center coordinates (hence can be easily reused),
    // which covers most of the real-world use cases when user navigates in more or less the same area.
    private static let memoizedGeohashesLock = NSRecursiveLock()
    private static var memoizedGeohashes = [MemoizationKey: Code]()
    private struct MemoizationKey: Hashable {
        let coordinate: CLLocationCoordinate2D, length: Int
    }

    /// Decodes given geohash string to a coordinate with the corresponding floating point precision.
    ///
    /// Will return nil if string is invalid.
    ///
    /// Valid geohash string should consist of the characters from this set: `0123456789bcdefghjkmnpqrstuvwxyz`
    ///
    /// Example:
    /// ```
    /// let coord = GeoHash.decode(geohash: "dr5ru7c02wnv")
    /// // CLLocationCoordinate2D(latitude: 40.75798, longitude: -73.991516)
    /// ```
    public static func decode(geohash: Code) -> CLLocationCoordinate2D? {
        guard let box = Box(geohash: geohash) else {
            return nil
        }
        let center = box.center
        // calculate correct precision for the center coordinate
        let latPrecisionMult = pow(10, max(1, (-log(box.northEast.latitude - box.southWest.latitude) / M_LN10).rounded(.down)))
        let lonPrecisionMult = pow(10, max(1, (-log(box.northEast.longitude - box.southWest.longitude) / M_LN10).rounded(.down)))
        // fail if result is invalid
        return latPrecisionMult.isInfinite || latPrecisionMult.isNaN || lonPrecisionMult.isInfinite || lonPrecisionMult.isNaN
            ? nil
            : CLLocationCoordinate2D(
                latitude: (center.latitude * latPrecisionMult).rounded() / latPrecisionMult,
                longitude: (center.longitude * lonPrecisionMult).rounded() / lonPrecisionMult
            )
    }

    public enum Direction: Equatable {
        case north, east, west, south
    }

    /// Represents a bounding box for a given geohash.
    ///
    /// Can be constructed by either providing a coordinate with required geohash length, or by providing a geohash string.
    /// Contains geohash string and four vertices of its bounding box.
    public struct Box: Equatable {
        public let geohash: Code
        public let northEast: CLLocationCoordinate2D
        public let southWest: CLLocationCoordinate2D

        public var northWest: CLLocationCoordinate2D { return .init(latitude: northEast.latitude, longitude: southWest.longitude) }
        public var southEast: CLLocationCoordinate2D { return .init(latitude: southWest.latitude, longitude: northEast.longitude) }

        public var center: CLLocationCoordinate2D {
            return CLLocationCoordinate2D(
                latitude: (southWest.latitude + northEast.latitude) / 2,
                longitude: (southWest.longitude + northEast.longitude) / 2
            )
        }

        /// Provides 4 vertice coordinates in a clockwise direction starting with `ne`.
        public var vertices: [CLLocationCoordinate2D] { return [northEast, southEast, southWest, northWest] }

        /// Construct a box by providing a coordinate and required geohash string length between 1 and 22.
        public init(coordinate: CLLocationCoordinate2D, length: Int) {
            // correct inputs to not fail encoding
            let coord = CLLocationCoordinate2D(
                latitude: coordinate.latitude.inRange(min: world.lat.min, max: world.lat.max),
                longitude: coordinate.longitude.inRange(min: world.lon.min, max: world.lon.max)
            )
            let length = length.inRange(min: geohashLengthBounds.min, max: geohashLengthBounds.max)

            var (lat, lon) = world
            var geohash = ""
            var charIdx = 0
            var bit = base32CharFirstBit
            var bitParity = Parity.even
            // construct geohash string of length defined by a length number,
            // by searching corresponding cell in a grid while zooming in to a given length,
            // and calculating & storing longitude char per every even bit, and latitude char per every odd bit in bitmask
            while geohash.count < length {
                if bitParity == .even {
                    let lonMid = (lon.min + lon.max) / 2
                    if coord.longitude >= lonMid {
                        charIdx |= bit
                        lon.min = lonMid
                    } else {
                        lon.max = lonMid
                    }
                } else {
                    let latMid = (lat.min + lat.max) / 2
                    if coord.latitude >= latMid {
                        charIdx |= bit
                        lat.min = latMid
                    } else {
                        lat.max = latMid
                    }
                }
                // shift to the next bit
                bit >>= 1
                bitParity.toggle()
                // collect character and start over once reached end
                if bit == base32CharLastBit {
                    geohash.append(base32EncodeTable[charIdx])
                    bit = base32CharFirstBit
                    charIdx = 0
                }
            }
            self.northEast = CLLocationCoordinate2D(latitude: lat.max, longitude: lon.max)
            self.southWest = CLLocationCoordinate2D(latitude: lat.min, longitude: lon.min)
            self.geohash = geohash
        }

        public init?(geohash: Code) {
            guard !geohash.isEmpty else {
                return nil
            }
            var (lat, lon) = world
            var bitParity = Parity.even

            for char in geohash {
                guard let charIdx = base32DecodeTable[char] else {
                    return nil
                }
                var bit = base32CharFirstBit
                while bit != base32CharLastBit {
                    let bitN = charIdx & bit
                    if bitParity == .even {
                        let lonMid = (lon.min + lon.max) / 2
                        if bitN != 0 {
                            lon.min = lonMid
                        } else {
                            lon.max = lonMid
                        }
                    } else {
                        let latMid = (lat.min + lat.max) / 2
                        if bitN != 0 {
                            lat.min = latMid
                        } else {
                            lat.max = latMid
                        }
                    }
                    // shift to the next bit
                    bit >>= 1
                    bitParity.toggle()
                }
            }
            self.northEast = CLLocationCoordinate2D(latitude: lat.max, longitude: lon.max)
            self.southWest = CLLocationCoordinate2D(latitude: lat.min, longitude: lon.min)
            self.geohash = geohash
        }
    }
}

// MARK: - Utils

private extension Array where Element == GeoHash.Code.Element {
    /// Constructs a character per its index table out of array.
    var charAtIdxTable: [GeoHash.Code.Element: Int] {
        enumerated().reduce(into: [:]) { acc, charAtIdx in
            acc[charAtIdx.element] = charAtIdx.offset
        }
    }
}

// MARK: - Precision

extension GeoHash {
    public enum Precision: Int { case km2500 = 1, km630, km78, km20, m2400, m610, m76, m19, cm240, cm60, mm74 }

    public static func encode(coordinate: CLLocationCoordinate2D, precision: Precision) -> Code {
        return encode(coordinate: coordinate, length: precision.rawValue)
    }
}

// MARK: - Neighbors

public typealias GeoHashNeighbors = GeoHash.Neighbors<GeoHash.Code>

extension GeoHash {
    public struct Neighbors<T> {
        public let north: T, east: T, south: T, west: T
        public let northEast: T, southEast: T, southWest: T, northWest: T

        /// Provides all neighbors as an array, in a clockwise direction starting with `n`.
        public var all: [T] {
            [north, northEast, east, southEast, south, southWest, west, northWest]
        }
    }

    /// Provides an adjacent in specified direction for a rect by a given geohash.
    public static func adjacent(geohash: Code, direction: Direction) -> Code? {
        guard let lastChar = geohash.last else {
            return nil
        }
        var parent: Code? = Code(geohash.dropLast())
        let parity = geohash.count.isMultiple(of: 2) ? Parity.even : .odd

        // in case case they don't share common prefix
        if bordersDecodeTable[direction]?[parity]?[lastChar] != nil {
            parent = parent.flatMap { adjacent(geohash: $0, direction: direction) }
        }
        // append adjacent character by its position in original alphabet
        return zip(parent, neighborsDecodeTable[direction]?[parity]?[lastChar].map { base32EncodeTable[$0] })
            .map { parent, adjacentChar in
                var parent = parent
                parent.append(adjacentChar)
                return parent
            }
    }

    /// Provides all 8 neighboring geohashes for a given geohash.
    public static func neighbors(geohash: Code) -> GeoHashNeighbors? {
        return GeoHashNeighbors(geohash: geohash)
    }

    /// Returns code for parent geohash block if there's one, otherwise - nil.
    public static func parent(geohash: Code) -> Code? {
        guard geohash.count > 1 else {
            return nil
        }
        return Code(geohash.dropLast(1))
    }
}

extension GeoHashNeighbors {
    public init?(geohash: GeoHash.Code) {
        guard
            let north = GeoHash.adjacent(geohash: geohash, direction: .north),
            let east = GeoHash.adjacent(geohash: geohash, direction: .east),
            let south = GeoHash.adjacent(geohash: geohash, direction: .south),
            let west = GeoHash.adjacent(geohash: geohash, direction: .west),
            let northEast = GeoHash.adjacent(geohash: north, direction: .east),
            let southEast = GeoHash.adjacent(geohash: south, direction: .east),
            let southWest = GeoHash.adjacent(geohash: south, direction: .west),
            let northWest = GeoHash.adjacent(geohash: north, direction: .west)
        else {
            return nil
        }
        self.north = north
        self.east = east
        self.south = south
        self.west = west
        self.northEast = northEast
        self.southEast = southEast
        self.southWest = southWest
        self.northWest = northWest
    }
}

extension GeoHash.Neighbors: Equatable where T: Equatable {}
extension GeoHash.Neighbors: Hashable where T: Hashable {}
