import CoreLocation
import GEOSwift
import WhimCore
import RxSwift

final class DetailsMap: WhimScenePresentation {
    typealias State = DetailsStore.State.Map

    enum Action {
    }

    var output: DetailsMap.Dispatch?

    private let disposeBag = DisposeBag()
    private let mapLayerManager: DemoMapLayerManager
    private let map: (layer: DemoMapLayer, lifetime: MapLayerLifetime)

    private var isActive: Bool = false

    init(mapLayerManager: DemoMapLayerManager) {
        self.mapLayerManager = mapLayerManager
        self.map = mapLayerManager.registerNewLayer(with: .details)

        setupMapLayer()
    }

    private func setupMapLayer() {
        // Config map layer and bind to its events here
    }

    func render(state: State) {
        if let country = state.country.value, map.layer.overlays.isEmpty || map.layer.overlays.first?.polygon?.title != country.name {
            map.layer.setCenter(country.coordinate, zoomLevel: 5, animated: true)
            switch country.geometry {
            case let .polygon(polygon):
                renderPolygon(polygon, for: country.name)

            case let .multiPolygon(multiPolygon):
                for polygon in multiPolygon.polygons {
                    renderPolygon(polygon, for: country.name)
                }

            default:
                break
            }
        }
        applyActiveState(state.isActive)
    }

    private func renderPolygon(_ polygon: Polygon, for countryName: CountryName) {
        let coords = polygon.exterior.points.map { CLLocationCoordinate2D(latitude: $0.y, longitude: $0.x) }
        let holes = polygon.holes.map { hole in
            MapPolygon(
                coordinates: hole.points.map { CLLocationCoordinate2D(latitude: $0.y, longitude: $0.x) },
                lineWidth: 1
            )
        }
        map.layer.overlays.append(
            .polygon(MapPolygon(
                title: countryName,
                coordinates: coords,
                interiorPolygons: holes,
                lineWidth: 1,
                fillColor: .yellow.withAlphaComponent(0.5)
            ))
        )
    }

    private func applyActiveState(_ isActive: Bool) {
        guard isActive != self.isActive else {
            return
        }
        if isActive {
            mapLayerManager.requestControlForLayer(with: map.layer.token) { ctx in
                return .none
            }
        } else {
            mapLayerManager.relinquishControlForLayer(with: map.layer.token)
        }
        self.isActive = isActive
    }
}
