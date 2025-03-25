import CoreLocation
import GEOSwift
import WhimCore
import RxSwift
import OrderedCollections

final class DetailsMap: WhimScenePresentation {
    typealias State = DetailsStore.State.Map

    enum Action {
        case didUpdateVisibleCoordinate(CLLocationCoordinate2D)
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
        map.layer.events.compactMap(\.map?.changingPosition)
            .filter(\.status.isEnded)
            .debounce(.milliseconds(500), scheduler: MainScheduler.asyncInstance)
            .map(\.center)
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] coordinate in
                self?.dispatch(.didUpdateVisibleCoordinate(coordinate))
            })
            .disposed(by: disposeBag)
    }

    func render(state newState: State) {
        applyVisibleCoordinate(newState.visibleCoordinate)
        applyCountry(newState.country)
        applyActiveState(newState.isActive)
    }

    private func applyVisibleCoordinate(_ coordinate: CLLocationCoordinate2D?) {
        guard let coordinate else {
            return
        }
        if map.layer.centerCoordinate.distance(to: coordinate) > 25 {
            map.layer.setCenter(coordinate, zoomLevel: 5, animated: true)
        }
    }

    private func applyCountry(_ countryStatus: DemoLoadingStatus<DetailsStore.State.CountryInfo>) {
        guard let country = countryStatus.value else {
            return map.layer.overlays.removeAll()
        }
        guard map.layer.overlays.isEmpty || map.layer.overlays.first?.polygon?.userData as? String != country.name else {
            return
        }

        map.layer.setCenter(country.coordinate, zoomLevel: 5, animated: true)
        map.layer.overlays = mapOverlays(from: country.geometry, for: country.name)
    }

    private func mapOverlays(from geometry: Geometry, for countryName: CountryName) -> OrderedSet<MapOverlay> {
        return switch geometry {
        case let .point(point):
            [.circle(mapCircle(from: point, for: countryName))]

        case let .multiPoint(multyPoint):
            multyPoint.points.reduce(into: []) { acc, point in
                acc.append(.circle(mapCircle(from: point, for: countryName)))
            }

        case let .lineString(line):
            [.polyline(mapPolyline(from: line, for: countryName))]

        case let .multiLineString(multiLine):
            multiLine.lineStrings.reduce(into: []) { acc, line in
                acc.append(.polyline(mapPolyline(from: line, for: countryName)))
            }

        case let .polygon(polygon):
            [.polygon(mapPolygon(from: polygon, for: countryName))]

        case let .multiPolygon(multiPolygon):
            multiPolygon.polygons.reduce(into: []) { acc, polygon in
                acc.append(.polygon(mapPolygon(from: polygon, for: countryName)))
            }

        case let .geometryCollection(geometryCollection):
            geometryCollection.geometries.reduce(into: []) { acc, geometry in
                acc.append(contentsOf: mapOverlays(from: geometry, for: countryName))
            }
        }
    }

    private func mapCircle(from point: Point, for countryName: CountryName) -> MapCircle {
        MapCircle(
            coordinate: point.coordinate,
            radius: 5,
            lineWidth: 1,
            fillColor: .yellow.withAlphaComponent(0.2),
            userData: countryName
        )
    }

    private func mapPolyline(from line: LineString, for countryName: CountryName) -> MapPolyline {
        MapPolyline(coordinates: line.points.map(\.coordinate), lineWidth: 1, userData: countryName)
    }

    private func mapPolygon(from polygon: Polygon, for countryName: CountryName) -> MapPolygon {
        let coords = polygon.exterior.points.map(\.coordinate)
        let holes = polygon.holes.map { hole in
            MapPolygon(
                coordinates: hole.points.map(\.coordinate),
                lineWidth: 1,
                userData: countryName
            )
        }
        return MapPolygon(
            title: countryName,
            coordinates: coords,
            interiorPolygons: holes,
            lineWidth: 1,
            fillColor: .yellow.withAlphaComponent(0.2),
            userData: countryName
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

extension Point {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: y, longitude: x)
    }
}


extension CLLocationCoordinate2D {
    /// distance in meters
    func distance(to: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude).distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }

}
