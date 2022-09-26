import Foundation
import MapKit

// Extended MapKit overlays to bridge between our custom overlays.
// Each overlay has token of a layer it belongs to. This way we can easily keep track of layer's overlays and manage them.
//
// From what I've seen, we don't mutate any of overlays' values and don't interact with them besides simple tap,
// so I decided to not introduce additional complexity and designed overlays being immutable.

public protocol AppleMapsOverlay: MKOverlay {
    var layerToken: MapLayerToken? { get }
    var overlayData: MapOverlay? { get }
}

// MARK: Polyline

public final class AppleMapsPolyline: MKPolyline, AppleMapsOverlay {
    public private(set) var layerToken: MapLayerToken?
    public private(set) var data: MapPolyline?

    public var overlayData: MapOverlay? { data.map(MapOverlay.polyline) }

    public convenience init(polyline: MapPolyline, layerToken: MapLayerToken) {
        self.init(coordinates: polyline.coordinates, count: polyline.coordinates.count)

        self.layerToken = layerToken
        self.data = polyline
    }
}

public final class AppleMapsPolylineRenderer: MKPolylineRenderer {
    public convenience init(polyline: AppleMapsPolyline) {
        self.init(overlay: polyline)

        guard let data = polyline.data else { return }

        lineWidth = data.lineWidth
        strokeColor = data.strokeColor
        lineDashPattern = data.lineDashPattern
        lineCap = data.lineCap
        lineJoin = data.lineJoin
        alpha = data.alpha
    }

    private override init(overlay: MKOverlay) {
        super.init(overlay: overlay)
    }
}

// MARK: Polygon

public final class AppleMapsPolygon: MKPolygon, AppleMapsOverlay {
    public private(set) var layerToken: MapLayerToken?
    public private(set) var data: MapPolygon?

    public var overlayData: MapOverlay? { data.map(MapOverlay.polygon) }

    public convenience init(polygon: MapPolygon, layerToken: MapLayerToken) {
        self.init(
            coordinates: polygon.coordinates,
            count: polygon.coordinates.count,
            interiorPolygons: polygon.interiorPolygons?.map { AppleMapsPolygon(polygon: $0, layerToken: layerToken) }
        )
        self.title = polygon.title
        self.layerToken = layerToken
        self.data = polygon
    }
}

public final class AppleMapsPolygonRenderer: MKPolygonRenderer {
    public init(polygon: AppleMapsPolygon) {
        super.init(polygon: polygon)

        guard let data = polygon.data else { return }

        lineWidth = data.lineWidth
        strokeColor = data.strokeColor
        fillColor = data.fillColor
        lineDashPattern = data.lineDashPattern
        lineCap = data.lineCap
        lineJoin = data.lineJoin
        alpha = data.alpha
    }
}

// MARK: Circle

public final class AppleMapsCircle: MKCircle, AppleMapsOverlay {
    public private(set) var layerToken: MapLayerToken?
    public private(set) var data: MapCircle?

    public var overlayData: MapOverlay? { data.map(MapOverlay.circle) }

    public convenience init(circle: MapCircle, layerToken: MapLayerToken) {
        self.init(center: circle.coordinate, radius: circle.radius)

        self.layerToken = layerToken
        self.data = circle
    }
}

public final class AppleMapsCircleRenderer: MKCircleRenderer {
    public init(circle: AppleMapsCircle) {
        super.init(circle: circle)

        guard let data = circle.data else { return }

        lineWidth = data.lineWidth
        strokeColor = data.strokeColor
        fillColor = data.fillColor
        lineDashPattern = data.lineDashPattern
        alpha = data.alpha
    }
}
