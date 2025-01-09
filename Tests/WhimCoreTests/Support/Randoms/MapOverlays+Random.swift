import CoreLocation
import CoreGraphics
import UIKit
import WhimRandom
import WhimCore

extension MapMarker: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        MapMarker(
            coordinate: .random(using: &generator),
            icon: .random(using: &generator),
            centerOffset: .random(using: &generator),
            alpha: .random(in: 0...1, using: &generator),
            animatesWhenAdded: .random(using: &generator),
            clusteringIdentifier: .random(using: &generator),
            userData: nil
        ) as! Self
    }

    public static func random(
        coordinate: CLLocationCoordinate2D = .random(using: &R),
        icon: Icon? = .random(using: &R),
        centerOffset: CGPoint = .random(using: &R),
        alpha: CGFloat = .random(using: &R),
        animatesWhenAdded: Bool = .random(using: &R),
        clusteringIdentifier: String? = .random(using: &R),
        userData: Any? = nil
    ) -> MapMarker {
        MapMarker(
            coordinate: coordinate,
            icon: icon,
            centerOffset: centerOffset,
            alpha: alpha,
            animatesWhenAdded: animatesWhenAdded,
            clusteringIdentifier: clusteringIdentifier,
            userData: userData
        )
    }
}

extension MapCluster: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        Self.makeDefault(
            identifier: .random(using: &generator),
            items: .random(using: &generator)
        ) as! Self
    }

    public static func random(
        identifier: MapClusteringIdentifier = .random(using: &R),
        items: Set<MapClusterItem> = .random(using: &R)
    ) -> MapCluster {
        MapCluster.makeDefault(identifier: identifier, items: items)
    }
}

extension MapClusterMarker: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        MapClusterMarker(
            cluster: .random(using: &generator),
            icon: .random(using: &generator),
            centerOffset: .random(using: &generator),
            alpha: .random(using: &generator),
            deselectWhenSelected: .random(using: &generator),
            userData: nil
        ) as! Self
    }

    public static func random(
        cluster: MapCluster = .random(using: &R),
        icon: MapMarker.Icon? = .random(using: &R),
        centerOffset: CGPoint = .random(using: &R),
        alpha: CGFloat = .random(using: &R),
        deselectWhenSelected: Bool = .random(using: &R),
        userData: Any? = nil
    ) -> MapClusterMarker {
        MapClusterMarker(
            cluster: cluster,
            icon: icon,
            centerOffset: centerOffset,
            alpha: alpha,
            deselectWhenSelected: deselectWhenSelected,
            userData: userData
        )
    }
}

extension MapCircle: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapCircle {
        MapCircle(
            coordinate: .random(using: &generator),
            radius: .random(using: &generator),
            lineWidth: .random(using: &generator),
            strokeColor: .random(using: &generator),
            fillColor: .random(using: &generator),
            lineDashPattern: .random(using: &generator),
            alpha: .random(using: &generator),
            userData: nil
        )
    }

    public static func random(
        coordinate: CLLocationCoordinate2D = .random(using: &R),
        radius: CLLocationDistance = .random(using: &R),
        lineWidth: CGFloat = .random(using: &R),
        strokeColor: UIColor? = .random(using: &R),
        fillColor: UIColor? = .random(using: &R),
        lineDashPattern: [NSNumber]? = .random(using: &R),
        alpha: CGFloat = .random(using: &R),
        userData: Any? = nil
    ) -> MapCircle {
        MapCircle(
            coordinate: coordinate,
            radius: radius,
            lineWidth: lineWidth,
            strokeColor: strokeColor,
            fillColor: fillColor,
            lineDashPattern: lineDashPattern,
            alpha: alpha,
            userData: userData
        )
    }
}

extension MapPolygon: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapPolygon {
        MapPolygon(
            title: .random(using: &generator),
            coordinates: .random(using: &generator),
            interiorPolygons: nil, // can easily fall into recursion when creating interior polygons, thus - just `nil`
            lineWidth: .random(using: &generator),
            strokeColor: .random(using: &generator),
            fillColor: .random(using: &generator),
            lineDashPattern: .random(using: &generator),
            lineCap: .random(using: &generator),
            lineJoin: .random(using: &generator),
            alpha: .random(using: &generator),
            userData: nil
        )
    }

    public static func random(
        title: String? = .random(using: &R),
        coordinates: [CLLocationCoordinate2D] = .random(using: &R),
        interiorPolygons: [MapPolygon]? = nil, // can easily fall into recursion when creating interior polygons, thus - just `nil`
        lineWidth: CGFloat = .random(using: &R),
        strokeColor: UIColor? = .random(using: &R),
        fillColor: UIColor? = .random(using: &R),
        lineDashPattern: [NSNumber]? = .random(using: &R),
        lineCap: CGLineCap = .random(using: &R),
        lineJoin: CGLineJoin = .random(using: &R),
        alpha: CGFloat = .random(using: &R),
        userData: Any? = nil
    ) -> MapPolygon {
        MapPolygon(
            title: title,
            coordinates: coordinates,
            interiorPolygons: interiorPolygons,
            lineWidth: lineWidth,
            strokeColor: strokeColor,
            fillColor: fillColor,
            lineDashPattern: lineDashPattern,
            lineCap: lineCap,
            lineJoin: lineJoin,
            alpha: alpha,
            userData: userData
        )
    }
}

extension MapPolyline: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapPolyline {
        MapPolyline(
            coordinates: .random(using: &generator),
            lineWidth: .random(using: &generator),
            strokeColor: .random(using: &generator),
            lineDashPattern: .random(using: &generator),
            lineCap: .random(using: &generator),
            lineJoin: .random(using: &generator),
            alpha: .random(using: &generator),
            userData: nil
        )
    }

    public static func random(
        coordinates: [CLLocationCoordinate2D] = .random(using: &R),
        lineWidth: CGFloat = .random(using: &R),
        strokeColor: UIColor? = .random(using: &R),
        lineDashPattern: [NSNumber]? = .random(using: &R),
        lineCap: CGLineCap = .random(using: &R),
        lineJoin: CGLineJoin = .random(using: &R),
        alpha: CGFloat = .random(using: &R),
        userData: Any? = nil
    ) -> MapPolyline {
        MapPolyline(
            coordinates: coordinates,
            lineWidth: lineWidth,
            strokeColor: strokeColor,
            lineDashPattern: lineDashPattern,
            lineCap: lineCap,
            lineJoin: lineJoin,
            alpha: alpha,
            userData: userData
        )
    }
}
