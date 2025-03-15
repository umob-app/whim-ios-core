import MapKit

/// ProximityHash generates a set of geohashes that cover a given region area (circular or rectangular),
/// with the required length of geohash and bounding rule.
///
/// Based on [proximityhash](https://github.com/ashwin711/proximityhash) .
/// However, instead of operating grid cells dimensions in distances (m/km), which change from equator to the poles,
/// we operate with degrees deltas that are always the same. This gives us exactly precise results, unlike original version.
public enum ProximityHash {
    private static let geohashLengthBounds = (min: 1, max: 12)

    private static let minCellsToCheck = 2

    /// Precalculted spans for grid cells at given precision (1-12).
    /// They're always of the same values no matter what location you need, whether close to equator or close to the poles.
    private static let gridSpans = [
        MKCoordinateSpan(latitudeDelta: 45.0, longitudeDelta: 45.0),
        MKCoordinateSpan(latitudeDelta: 5.625, longitudeDelta: 11.25),
        MKCoordinateSpan(latitudeDelta: 1.40625, longitudeDelta: 1.40625),
        MKCoordinateSpan(latitudeDelta: 0.17578125, longitudeDelta: 0.3515625),
        MKCoordinateSpan(latitudeDelta: 0.0439453125, longitudeDelta: 0.0439453125),
        MKCoordinateSpan(latitudeDelta: 0.0054931640625, longitudeDelta: 0.010986328125),
        MKCoordinateSpan(latitudeDelta: 0.001373291015625, longitudeDelta: 0.001373291015625),
        MKCoordinateSpan(latitudeDelta: 0.000171661376953125, longitudeDelta: 0.00034332275390625),
        MKCoordinateSpan(latitudeDelta: 4.291534423828125e-05, longitudeDelta: 4.291534423828125e-05),
        MKCoordinateSpan(latitudeDelta: 5.364418029785156e-06, longitudeDelta: 1.0728836059570312e-05),
        MKCoordinateSpan(latitudeDelta: 1.341104507446289e-06, longitudeDelta: 1.341104507446289e-06),
        MKCoordinateSpan(latitudeDelta: 1.6763806343078613e-07, longitudeDelta: 3.3527612686157227e-07)
    ]

    /// Represents the bounds of geohashes inside the region area.
    public enum Bounds: Equatable {
        /// Collects geohashes that intersect with the circular area even a bit.
        case intersecting
        /// Collects geohashes that are fully included by the circle area.
        case included
    }

    /// Generates a set of geohashes that approximate a circle.
    ///
    /// There will always be at least center point's geohash,
    /// no matter what bounds preference is and how small the region area is, even if it's smaller than the geohash cell.
    ///
    /// - Parameters:
    ///   - region: region of the area we want to calculate geohashes for
    ///   - length: length of geohash strings from 1 to 12. The higher the number, the smaller the cells will be
    ///   - bounds: a preference to either get fully included geohashes inside a region area,
    ///     or to keep geohashes that intersect region area even a bit
    /// - Returns: unqiue set of geohash strings
    public static func geohashes(
        inRegion region: AreaRegion,
        ofLength length: Int,
        includingIntersecting: Bool = true
    ) -> [GeoHash.Code: Bounds] {
        // keep length in supported range
        let length = length.inRange(min: geohashLengthBounds.min, max: geohashLengthBounds.max)
        let span = gridSpans[length - 1]
        // constructing a bounding rect to get its span deltas in degrees
        let regionBoundingRect = region.boundingRect
        let regionLatSpan = min(regionBoundingRect.span.latitudeDelta, GeoHash.world.lat.max)
        let regionLonSpan = min(regionBoundingRect.span.longitudeDelta, GeoHash.world.lon.max)
        let (regionLatSemiSpan, regionLonSemiSpan) = (regionLatSpan / 2, regionLonSpan / 2)
        // calculating number of cells inside this rect in vertical and horizontal directions
        let latCells = max(minCellsToCheck, Int((regionLatSpan / span.latitudeDelta).rounded(.up)))
        let lonCells = max(minCellsToCheck, Int((regionLonSpan / span.longitudeDelta).rounded(.up)))
        // calculating center of the geohash bounding box for the given area center,
        // to help precisely move from one box to another using span deltas for the given precision
        let center = region.center
        let bbox = GeoHash.Box(coordinate: center, length: length)
        let origin = bbox.center
        // for included preference, no need to perform any extra work if region area is smaller than the cell
        if !includingIntersecting && (span.latitudeDelta >= regionLatSpan || span.longitudeDelta >= regionLonSpan) {
            return [bbox.geohash: .included]
        }
        var points: [CLLocationCoordinate2D: Bounds] = [:]
        // we start moving from the center of the area in the north-east direction,
        // and for each such move we generate 4 points equally-distanced from the center in all 4 directions (ne, se, sw, nw).
        // this way we can work within each sector of the region area and reduce cost of checking if cell falls into it.
        for latCellIdx in 0 ..< latCells {
            let latDiff = span.latitudeDelta * Double(latCellIdx)
            // all coordinates' calculations should respect max and min coordinates on the map to wrap their values around them
            // i.e. we can't have longitude greater than 180 or less than -180,
            // and if we do, we should move remainder to the 'other side', so that 185 would become -175, and same for longitude.
            let northLat = corrected(lat: origin.latitude + latDiff)
            let southLat = corrected(lat: origin.latitude - latDiff)

            for lonCellIdx in 0 ..< lonCells {
                let lonDiff = span.longitudeDelta * Double(lonCellIdx)

                let eastLon = corrected(lon: origin.longitude + lonDiff)
                let westLon = corrected(lon: origin.longitude - lonDiff)

                // constructing 4 cells - 1 for each sector of the region area
                let nw = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: northLat, longitude: westLon), span: span)
                let ne = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: northLat, longitude: eastLon), span: span)
                let se = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: southLat, longitude: eastLon), span: span)
                let sw = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: southLat, longitude: westLon), span: span)

                if lonCellIdx == 0 {
                    let xs = lonMidBoundPoints(region: region, latSemiSpan: regionLatSemiSpan, sectors: (nw, ne, se, sw), includingIntersecting: includingIntersecting)
                    points.merge(xs) { _, new in new }
                } else if latCellIdx == 0 {
                    let xs = latMidBoundPoints(region: region, lonSemiSpan: regionLonSemiSpan, sectors: (nw, ne, se, sw), includingIntersecting: includingIntersecting)
                    points.merge(xs) { _, new in new }
                } else {
                    let xs = boundPoints(region: region, sectors: (nw, ne, se, sw), includingIntersecting: includingIntersecting)
                    points.merge(xs) { _, new in new }
                }
            }
        }
        // we always include coordinate's geohash in any case
        return points.reduce(into: [bbox.geohash: .included]) { acc, boundedPoint in
            acc[GeoHash.encode(coordinate: boundedPoint.key, length: length)] = boundedPoint.value
        }
    }

    private static func latMidBoundPoints(
        region: AreaRegion,
        lonSemiSpan: CLLocationDistance,
        sectors: (nw: MKCoordinateRegion, ne: MKCoordinateRegion, se: MKCoordinateRegion, sw: MKCoordinateRegion),
        includingIntersecting: Bool
    ) -> [CLLocationCoordinate2D: Bounds] {
        // some hacks to avoid even more complex calculations:
        //
        // the only cells that can intersect region area, without having any of their vertices inside that area,
        // is when cells intersect it with their edges, yet not too far to intersect it with any of their vertex.
        // i.e. like this:
        //     ___
        //   _/   \_ +–––––+              +–––––+
        //  /       \|     |        +––––––––+  |
        // (         |)    |   OR   |     |  |  |
        //  \_     _/|     |        +––––––––+  |
        //    \___/  +–––––+              +–––––+
        //
        // this can happen to only 4 cells, coming from the north, south, east and west,
        // that's why we check each cell only in 0 latitude and 0 longitude positions for exactly this case.
        //
        // thus, in longitude 0 position, we check each cell's latitude edge which is closer to the center,
        // and if that edge is closer to the center than region's latitude radius, then it intersects that area.
        //
        // same is true for the longitude direction (see `lonMidPoints` method), when latitude cell position is 0
        // and its longitude edge is closer to the center than region's longitude radius delta.
        var pts: [CLLocationCoordinate2D: Bounds] = [:]
        // north-west
        if region.contains(sectors.nw.nw) && region.contains(sectors.nw.sw) {
            pts[sectors.nw.center] = .included
        } else if includingIntersecting, abs(corrected(lon: sectors.nw.eLon - region.center.longitude)) < lonSemiSpan {
            pts[sectors.nw.center] = .intersecting
        }
        // north-east
        if region.contains(sectors.ne.ne) && region.contains(sectors.ne.se) {
            pts[sectors.ne.center] = .included
        } else if includingIntersecting, abs(corrected(lon: region.center.longitude - sectors.ne.wLon)) < lonSemiSpan {
            pts[sectors.ne.center] = .intersecting
        }
        // south-east
        if region.contains(sectors.se.se) && region.contains(sectors.se.ne) {
            pts[sectors.se.center] = .included
        } else if includingIntersecting, abs(corrected(lon: region.center.longitude - sectors.se.wLon)) < lonSemiSpan {
            pts[sectors.se.center] = .intersecting
        }
        // south-west
        if region.contains(sectors.sw.sw) && region.contains(sectors.sw.nw) {
            pts[sectors.sw.center] = .included
        } else if includingIntersecting, abs(corrected(lon: sectors.sw.eLon - region.center.longitude)) < lonSemiSpan {
            pts[sectors.sw.center] = .intersecting
        }
        return pts
    }

    private static func lonMidBoundPoints(
        region: AreaRegion,
        latSemiSpan: CLLocationDistance,
        sectors: (nw: MKCoordinateRegion, ne: MKCoordinateRegion, se: MKCoordinateRegion, sw: MKCoordinateRegion),
        includingIntersecting: Bool
    ) -> [CLLocationCoordinate2D: Bounds] {
        var pts: [CLLocationCoordinate2D: Bounds] = [:]
        // north-west
        if region.contains(sectors.nw.nw) && region.contains(sectors.nw.ne) {
            pts[sectors.nw.center] = .included
        } else if includingIntersecting, abs(corrected(lat: sectors.nw.sLat - region.center.latitude)) < latSemiSpan {
            pts[sectors.nw.center] = .intersecting
        }
        // north-east
        if region.contains(sectors.ne.ne) && region.contains(sectors.ne.nw) {
            pts[sectors.ne.center] = .included
        } else if includingIntersecting, abs(corrected(lat: sectors.ne.sLat - region.center.latitude)) < latSemiSpan {
            pts[sectors.ne.center] = .intersecting
        }
        // south-east
        if region.contains(sectors.se.se) && region.contains(sectors.se.sw) {
            pts[sectors.se.center] = .included
        } else if includingIntersecting, abs(corrected(lat: region.center.latitude - sectors.se.nLat)) < latSemiSpan {
            pts[sectors.se.center] = .intersecting
        }
        // south-west
        if region.contains(sectors.sw.sw) && region.contains(sectors.sw.se) {
            pts[sectors.sw.center] = .included
        } else if includingIntersecting, abs(corrected(lat: region.center.latitude - sectors.sw.nLat)) < latSemiSpan {
            pts[sectors.sw.center] = .intersecting
        }
        return pts
    }

    private static func boundPoints(
        region: AreaRegion,
        sectors: (nw: MKCoordinateRegion, ne: MKCoordinateRegion, se: MKCoordinateRegion, sw: MKCoordinateRegion),
        includingIntersecting: Bool
    ) -> [CLLocationCoordinate2D: Bounds] {
        // this is the most common case - for each cell in each of 4 sectors,
        // - included: we check if that cell's furthest point from the region center is contained in the region area,
        //   i.e. for the cell in `ne` sector, point to check would be `ne`.
        // - intersecting: we check if that cell's closest point to the region center is contained in the region area.
        //   i.e. for the cell in `ne` sector, point to check would be `sw`
        //
        // and it is cheaper than checking if all four vertices fall in a region area, but gives same result :)
        var pts: [CLLocationCoordinate2D: Bounds] = [:]
        // north-west
        if region.contains(sectors.nw.nw) {
            pts[sectors.nw.center] = .included
        } else if includingIntersecting, region.contains(sectors.nw.se) {
            pts[sectors.nw.center] = .intersecting
        }
        // north-east
        if region.contains(sectors.ne.ne) {
            pts[sectors.ne.center] = .included
        } else if includingIntersecting, region.contains(sectors.ne.sw) {
            pts[sectors.ne.center] = .intersecting
        }
        // south-east
        if region.contains(sectors.se.se) {
            pts[sectors.se.center] = .included
        } else if includingIntersecting, region.contains(sectors.se.nw) {
            pts[sectors.se.center] = .intersecting
        }
        // south-west
        if region.contains(sectors.sw.sw) {
            pts[sectors.sw.center] = .included
        } else if includingIntersecting, region.contains(sectors.sw.ne) {
            pts[sectors.sw.center] = .intersecting
        }
        return pts
    }
}

public extension ProximityHash {
    static func geohashes(
        aroundCoordinate center: CLLocationCoordinate2D,
        inRadius radius: CLLocationDistance,
        ofLength length: Int,
        includingIntersecting: Bool = true
    ) -> [GeoHash.Code: Bounds] {
        geohashes(inRegion: .circular(.init(center: center, radius: radius)), ofLength: length, includingIntersecting: includingIntersecting)
    }

    static func geohashes(
        inRect rect: MKCoordinateRegion,
        ofLength length: Int,
        includingIntersecting: Bool = true
    ) -> [GeoHash.Code: Bounds] {
        geohashes(inRegion: .rectangular(.init(region: rect)), ofLength: length, includingIntersecting: includingIntersecting)
    }
}

// MARK: - Utils

public extension MKCoordinateRegion {
    var wLon: CLLocationDegrees { corrected(lon: center.longitude - span.longitudeDelta / 2) }
    var eLon: CLLocationDegrees { corrected(lon: center.longitude + span.longitudeDelta / 2) }
    var nLat: CLLocationDegrees { corrected(lat: center.latitude + span.latitudeDelta / 2) }
    var sLat: CLLocationDegrees { corrected(lat: center.latitude - span.latitudeDelta / 2) }

    var nw: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: nLat, longitude: wLon) }
    var se: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: sLat, longitude: eLon) }
    var sw: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: sLat, longitude: wLon) }
    var ne: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: nLat, longitude: eLon) }

    var vertices: [CLLocationCoordinate2D] { [ne, se, sw, nw] }
}

public extension MKMapRect {
    init(_ region: MKCoordinateRegion) {
        let nw = MKMapPoint(region.nw)
        let se = MKMapPoint(region.se)

        self.init(
            origin: MKMapPoint(x: min(nw.x, se.x), y: min(nw.y, se.y)),
            size: MKMapSize(width: abs(nw.x - se.x), height: abs(nw.y - se.y))
        )
    }
}

/// Corrects longitude if it gets out of bounds.
/// i.e. 183 -> -177 or -196 -> 164
private func corrected(lon: CLLocationDegrees) -> CLLocationDegrees {
    if lon > GeoHash.world.lon.max {
        return GeoHash.world.lon.min + (lon - GeoHash.world.lon.max)
    } else if lon < GeoHash.world.lon.min {
        return GeoHash.world.lon.max + (lon - GeoHash.world.lon.min)
    }
    return lon
}

/// Corrects latitude if it gets out of bounds.
/// i.e. 93 -> -87 or -106 -> 74
private func corrected(lat: CLLocationDegrees) -> CLLocationDegrees {
    if lat > GeoHash.world.lat.max {
        return GeoHash.world.lat.min + (lat - GeoHash.world.lat.max)
    } else if lat < GeoHash.world.lat.min {
        return GeoHash.world.lat.max + (lat - GeoHash.world.lat.min)
    }
    return lat
}
