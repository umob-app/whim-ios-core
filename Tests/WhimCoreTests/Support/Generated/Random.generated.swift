// Generated using Sourcery 1.5.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// for stencil reference see: https://stencil.fuller.li/en/latest/index.html
// for sourcery reference see: https://cdn.rawgit.com/krzysztofzablocki/Sourcery/master/docs/index.html
// swiftlint:disable all

import Foundation
import WhimRandom
import CoreLocation
import MapKit
import RxSwift
import RxRelay

@testable import WhimCore

// MARK: - Structs

extension CircularRegion: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> CircularRegion {
        return CircularRegion(
            center: .random(using: &generator),
            radius: .random(using: &generator)
        )
    }

    static func random(
        center: CLLocationCoordinate2D = .random(using: &R),
        radius: CLLocationDistance = .random(using: &R)
    ) -> CircularRegion {
        return CircularRegion(
            center: center,
            radius: radius
        )
    }
}

extension CustomAnimatable: Random where T: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> CustomAnimatable {
        return CustomAnimatable(
            .random(using: &generator)
        )
    }

    static func random(
        _ value: T = .random(using: &R)
    ) -> CustomAnimatable {
        return CustomAnimatable(
            value
        )
    }
}

extension CustomAnimatable.Animation: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> CustomAnimatable.Animation {
        return CustomAnimatable.Animation(
            duration: .random(using: &generator),
            delay: .random(using: &generator),
            options: .random(using: &generator)
        )
    }

    static func random(
        duration: TimeInterval = .random(using: &R),
        delay: TimeInterval = .random(using: &R),
        options: UIView.AnimationOptions = .random(using: &R)
    ) -> CustomAnimatable.Animation {
        return CustomAnimatable.Animation(
            duration: duration,
            delay: delay,
            options: options
        )
    }
}

extension InterLayerProps: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> InterLayerProps {
        return InterLayerProps(
            position: .random(using: &generator),
            options: .random(using: &generator)
        )
    }

    static func random(
        position: Animatable<MapLayerVisibleRectInset.Position>? = .random(using: &R),
        options: Set<InterLayerProps.Options> = .random(using: &R)
    ) -> InterLayerProps {
        return InterLayerProps(
            position: position,
            options: options
        )
    }
}

extension MapClusterConfigs: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapClusterConfigs {
        return MapClusterConfigs(
            minimumClusterSize: .random(using: &generator),
            maximumClusterZoom: .random(using: &generator),
            animationDuration: .random(using: &generator)
        )
    }

    static func random(
        minimumClusterSize: Int = .random(using: &R),
        maximumClusterZoom: Double = .random(using: &R),
        animationDuration: Double? = .random(using: &R)
    ) -> MapClusterConfigs {
        return MapClusterConfigs(
            minimumClusterSize: minimumClusterSize,
            maximumClusterZoom: maximumClusterZoom,
            animationDuration: animationDuration
        )
    }
}

extension MapCoordinateSpan: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapCoordinateSpan {
        return MapCoordinateSpan(
            latitudeDelta: .random(using: &generator),
            longitudeDelta: .random(using: &generator)
        )
    }

    static func random(
        latitudeDelta: CLLocationDegrees = .random(using: &R),
        longitudeDelta: CLLocationDegrees = .random(using: &R)
    ) -> MapCoordinateSpan {
        return MapCoordinateSpan(
            latitudeDelta: latitudeDelta,
            longitudeDelta: longitudeDelta
        )
    }
}

extension MapLayerVisibleRectInset: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapLayerVisibleRectInset {
        return MapLayerVisibleRectInset(
            top: .random(using: &generator),
            bottom: .random(using: &generator),
            position: .random(using: &generator)
        )
    }

    static func random(
        top: MapLayerVisibleRectInset.Value = .random(using: &R),
        bottom: MapLayerVisibleRectInset.Value = .random(using: &R),
        position: MapLayerVisibleRectInset.Position = .random(using: &R)
    ) -> MapLayerVisibleRectInset {
        return MapLayerVisibleRectInset(
            top: top,
            bottom: bottom,
            position: position
        )
    }
}

extension MapMarker.Content: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapMarker.Content {
        return MapMarker.Content(
            icon: .random(using: &generator),
            centerOffset: .random(using: &generator)
        )
    }

    static func random(
        icon: MapMarker.Icon? = .random(using: &R),
        centerOffset: CGPoint = .random(using: &R)
    ) -> MapMarker.Content {
        return MapMarker.Content(
            icon: icon,
            centerOffset: centerOffset
        )
    }
}

extension MapRoutePlan: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapRoutePlan {
        return MapRoutePlan(
            source: .random(using: &generator),
            destination: .random(using: &generator),
            transportType: .random(using: &generator),
            renderWhen: .random(using: &generator),
            polylinesProvider: .random(using: &generator)
        )
    }

    static func random(
        source: CLLocationCoordinate2D = .random(using: &R),
        destination: CLLocationCoordinate2D = .random(using: &R),
        transportType: Set<MapRoutePlan.TransportType> = .random(using: &R),
        renderWhen: MapRoutePlan.RenderStrategy = .random(using: &R),
        polylinesProvider: FunctionObject<MapRoutePlan.Response, OrderedSet<MapPolyline>> = .random(using: &R)
    ) -> MapRoutePlan {
        return MapRoutePlan(
            source: source,
            destination: destination,
            transportType: transportType,
            renderWhen: renderWhen,
            polylinesProvider: polylinesProvider
        )
    }
}

extension MapRoutePlan.Response: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapRoutePlan.Response {
        return MapRoutePlan.Response(
            coordinates: .random(using: &generator),
            steps: .random(using: &generator)
        )
    }

    static func random(
        coordinates: [CLLocationCoordinate2D] = .random(using: &R),
        steps: [MapRoutePlan.Step] = .random(using: &R)
    ) -> MapRoutePlan.Response {
        return MapRoutePlan.Response(
            coordinates: coordinates,
            steps: steps
        )
    }
}

extension MapRoutePlan.Step: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapRoutePlan.Step {
        return MapRoutePlan.Step(
            coordinates: .random(using: &generator),
            transportType: .random(using: &generator)
        )
    }

    static func random(
        coordinates: [CLLocationCoordinate2D] = .random(using: &R),
        transportType: Set<MapRoutePlan.TransportType> = .random(using: &R)
    ) -> MapRoutePlan.Step {
        return MapRoutePlan.Step(
            coordinates: coordinates,
            transportType: transportType
        )
    }
}

extension MapSidebarItem.Custom: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapSidebarItem.Custom {
        return MapSidebarItem.Custom(
            id: .random(using: &generator),
            content: .random(using: &generator)
        )
    }

    static func random(
        id: Id = .random(using: &R),
        content: MapSidebarItem.Content = .random(using: &R)
    ) -> MapSidebarItem.Custom {
        return MapSidebarItem.Custom(
            id: id,
            content: content
        )
    }
}

extension MapZoomLevel.Padding: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapZoomLevel.Padding {
        return MapZoomLevel.Padding(
            factor: .random(using: &generator),
            insets: .random(using: &generator)
        )
    }

    static func random(
        factor: Double = .random(using: &R),
        insets: UIEdgeInsets = .random(using: &R)
    ) -> MapZoomLevel.Padding {
        return MapZoomLevel.Padding(
            factor: factor,
            insets: insets
        )
    }
}

extension RectangularRegion: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> RectangularRegion {
        return RectangularRegion(
            center: .random(using: &generator),
            span: .random(using: &generator)
        )
    }

    static func random(
        center: CLLocationCoordinate2D = .random(using: &R),
        span: MKCoordinateSpan = .random(using: &R)
    ) -> RectangularRegion {
        return RectangularRegion(
            center: center,
            span: span
        )
    }
}

extension VerticalInsets: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> VerticalInsets {
        return VerticalInsets(
            top: .random(using: &generator),
            bottom: .random(using: &generator)
        )
    }

    static func random(
        top: CGFloat = .random(using: &R),
        bottom: CGFloat = .random(using: &R)
    ) -> VerticalInsets {
        return VerticalInsets(
            top: top,
            bottom: bottom
        )
    }
}

// MARK: - Enums

extension AreaRegion: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [AreaRegion] {
        return [
            .circular(.random(using: &generator)),
            .rectangular(.random(using: &generator))
        ]
    }


    static func random(
        circular: AreaRegion = .circular(.random(using: &R)),
        rectangular: AreaRegion = .rectangular(.random(using: &R))
    ) -> AreaRegion {
        return [
            circular,
            rectangular
        ].randomElement(using: &R)!
    }
}

extension Icon: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [Icon] {
        return [
            .url(.random(using: &generator), .random(using: &generator)),
            .image(.random(using: &generator)),
            .asset(.random(using: &generator), .random(using: &generator)),
            .none
        ]
    }


    static func random(
        url: Icon = .url(.random(using: &R), .random(using: &R)),
        image: Icon = .image(.random(using: &R)),
        asset: Icon = .asset(.random(using: &R), .random(using: &R))
    ) -> Icon {
        return [
            url,
            image,
            asset,
            .none
        ].randomElement(using: &R)!
    }
}

extension Icon.Placeholder: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [Icon.Placeholder] {
        return [
            .image(.random(using: &generator)),
            .asset(.random(using: &generator), .random(using: &generator)),
            .none
        ]
    }


    static func random(
        image: Icon.Placeholder = .image(.random(using: &R)),
        asset: Icon.Placeholder = .asset(.random(using: &R), .random(using: &R))
    ) -> Icon.Placeholder {
        return [
            image,
            asset,
            .none
        ].randomElement(using: &R)!
    }
}

extension InterLayerProps.Options: Random {

    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> InterLayerProps.Options {
        return allCases.randomElement(using: &generator)!
    }
}

extension MapConfig: Random {

    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapConfig {
        return allCases.randomElement(using: &generator)!
    }
}

extension MapEvent: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [MapEvent] {
        return [
            .changingPosition(status: .random(using: &generator), center: .random(using: &generator), zoom: .random(using: &generator), heading: .random(using: &generator), span: .random(using: &generator)),
            .didUpdateVisibleRectInset(.random(using: &generator)),
            .didUpdateUserTracking(.random(using: &generator)),
            .didTapSidebarItem(.random(using: &generator)),
            .didTap(.random(using: &generator)),
            .didSelectMarker(.random(using: &generator), .random(using: &generator)),
            .didTapOnCluster(.random(using: &generator)),
            .didTapInsideOverlay(.random(using: &generator), .random(using: &generator)),
            .didStartCalculatingRoutes(.random(using: &generator)),
            .didFinishCalculatingRoutes(.random(using: &generator))
        ]
    }


    static func random(
        changingPosition: MapEvent = .changingPosition(status: .random(using: &R), center: .random(using: &R), zoom: .random(using: &R), heading: .random(using: &R), span: .random(using: &R)),
        didUpdateVisibleRectInset: MapEvent = .didUpdateVisibleRectInset(.random(using: &R)),
        didUpdateUserTracking: MapEvent = .didUpdateUserTracking(.random(using: &R)),
        didTapSidebarItem: MapEvent = .didTapSidebarItem(.random(using: &R)),
        didTap: MapEvent = .didTap(.random(using: &R)),
        didSelectMarker: MapEvent = .didSelectMarker(.random(using: &R), .random(using: &R)),
        didTapOnCluster: MapEvent = .didTapOnCluster(.random(using: &R)),
        didTapInsideOverlay: MapEvent = .didTapInsideOverlay(.random(using: &R), .random(using: &R)),
        didStartCalculatingRoutes: MapEvent = .didStartCalculatingRoutes(.random(using: &R)),
        didFinishCalculatingRoutes: MapEvent = .didFinishCalculatingRoutes(.random(using: &R))
    ) -> MapEvent {
        return [
            changingPosition,
            didUpdateVisibleRectInset,
            didUpdateUserTracking,
            didTapSidebarItem,
            didTap,
            didSelectMarker,
            didTapOnCluster,
            didTapInsideOverlay,
            didStartCalculatingRoutes,
            didFinishCalculatingRoutes
        ].randomElement(using: &R)!
    }
}

extension MapEvent.ChangingPositionStatus: Random {

    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapEvent.ChangingPositionStatus {
        return allCases.randomElement(using: &generator)!
    }
}

extension MapLayerEvent: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [MapLayerEvent] {
        return [
            .map(.random(using: &generator)),
            .didBecomeActive(.random(using: &generator))
        ]
    }


    static func random(
        map: MapLayerEvent = .map(.random(using: &R)),
        didBecomeActive: MapLayerEvent = .didBecomeActive(.random(using: &R))
    ) -> MapLayerEvent {
        return [
            map,
            didBecomeActive
        ].randomElement(using: &R)!
    }
}

extension MapLayerVisibleRectInset.Position: Random {

    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapLayerVisibleRectInset.Position {
        return allCases.randomElement(using: &generator)!
    }
}

extension MapLayerVisibleRectInset.Value: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [MapLayerVisibleRectInset.Value] {
        return [
            .custom(.random(using: &generator)),
            .automatic(.random(using: &generator))
        ]
    }


    static func random(
        custom: MapLayerVisibleRectInset.Value = .custom(.random(using: &R)),
        automatic: MapLayerVisibleRectInset.Value = .automatic(.random(using: &R))
    ) -> MapLayerVisibleRectInset.Value {
        return [
            custom,
            automatic
        ].randomElement(using: &R)!
    }
}

extension MapMarker.Icon: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [MapMarker.Icon] {
        return [
            .image(.random(using: &generator)),
            .view(.random(using: &generator))
        ]
    }


    static func random(
        image: MapMarker.Icon = .image(.random(using: &R)),
        view: MapMarker.Icon = .view(.random(using: &R))
    ) -> MapMarker.Icon {
        return [
            image,
            view
        ].randomElement(using: &R)!
    }
}

extension MapMarkerSelection: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [MapMarkerSelection] {
        return [
            .selecting(.random(using: &generator)),
            .selected(.random(using: &generator))
        ]
    }


    static func random(
        selecting: MapMarkerSelection = .selecting(.random(using: &R)),
        selected: MapMarkerSelection = .selected(.random(using: &R))
    ) -> MapMarkerSelection {
        return [
            selecting,
            selected
        ].randomElement(using: &R)!
    }
}

extension MapOverlay: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [MapOverlay] {
        return [
            .polyline(.random(using: &generator)),
            .polygon(.random(using: &generator)),
            .circle(.random(using: &generator))
        ]
    }


    static func random(
        polyline: MapOverlay = .polyline(.random(using: &R)),
        polygon: MapOverlay = .polygon(.random(using: &R)),
        circle: MapOverlay = .circle(.random(using: &R))
    ) -> MapOverlay {
        return [
            polyline,
            polygon,
            circle
        ].randomElement(using: &R)!
    }
}

extension MapReloadSidebarItemView.Style: Random {

    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapReloadSidebarItemView.Style {
        return allCases.randomElement(using: &generator)!
    }
}

extension MapRoutePlan.RenderStrategy: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [MapRoutePlan.RenderStrategy] {
        return [
            .always,
            .zoomLessThan(.random(using: &generator)),
            .zoomGreaterThan(.random(using: &generator))
        ]
    }


    static func random(
        zoomLessThan: MapRoutePlan.RenderStrategy = .zoomLessThan(.random(using: &R)),
        zoomGreaterThan: MapRoutePlan.RenderStrategy = .zoomGreaterThan(.random(using: &R))
    ) -> MapRoutePlan.RenderStrategy {
        return [
            .always,
            zoomLessThan,
            zoomGreaterThan
        ].randomElement(using: &R)!
    }
}

extension MapRoutePlan.Status: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [MapRoutePlan.Status] {
        return [
            .idle,
            .calculating,
            .finished(.random(using: &generator))
        ]
    }


    static func random(
        finished: MapRoutePlan.Status = .finished(.random(using: &R))
    ) -> MapRoutePlan.Status {
        return [
            .idle,
            .calculating,
            finished
        ].randomElement(using: &R)!
    }
}

extension MapRoutePlan.TransportType: Random {

    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> MapRoutePlan.TransportType {
        return allCases.randomElement(using: &generator)!
    }
}

extension MapSidebarItem.Content: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [MapSidebarItem.Content] {
        return [
            .image(.random(using: &generator), tintColor: nil),
            .view(.random(using: &generator))
        ]
    }


    static func random(
        image: MapSidebarItem.Content = .image(.random(using: &R), tintColor: nil),
        view: MapSidebarItem.Content = .view(.random(using: &R))
    ) -> MapSidebarItem.Content {
        return [
            image,
            view
        ].randomElement(using: &R)!
    }
}

extension MapZoomLevel: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [MapZoomLevel] {
        return [
            .zoom(.random(using: &generator)),
            .span(.random(using: &generator), .random(using: &generator))
        ]
    }


    static func random(
        zoom: MapZoomLevel = .zoom(.random(using: &R)),
        span: MapZoomLevel = .span(.random(using: &R), .random(using: &R))
    ) -> MapZoomLevel {
        return [
            zoom,
            span
        ].randomElement(using: &R)!
    }
}

