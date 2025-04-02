import WhimCore

typealias DemoMapLayerManager = MapLayerManager<DemoMapContext>
typealias DemoMapLayer = MapLayer<DemoMapContext>

enum DemoMapContext: Equatable {
    case landing
    case details
    // etc...
}
