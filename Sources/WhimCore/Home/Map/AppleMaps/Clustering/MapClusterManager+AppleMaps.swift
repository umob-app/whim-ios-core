import MapKit

extension MapClusterManager {
    /// Factory method that creates cluster manager with non-hierarchical distance-based algorithm and a default renderer.
    static func makeNonHierarchicalDistanceBased(
        identifier: MapClusteringIdentifier,
        layerToken: MapLayerToken,
        mapView: MKMapView,
        clusterMarkerProvider: MapClusterMarkerProvider?,
        clusterConfigsProvider: MapClusterConfigsProvider?
    ) -> MapClusterManager {
        return MapClusterManager(
            identifier: identifier,
//            zoomLevel: ObservableProperty(initial: mapView.zoomLevel, then: mapView.rx.zoomLevel),
            mapView: mapView,
            algorithm: AppleMapsClusterNonHierarchicalDistanceBasedAlgorithm(identifier: identifier, mapView: mapView),
            renderer: AppleMapsClusterDefaultRenderer(
                identifier: identifier,
                layerToken: layerToken,
                clusterMarkerProvider: clusterMarkerProvider,
                clusterConfigsProvider: clusterConfigsProvider,
                mapView: mapView
            )
        )
    }
}
