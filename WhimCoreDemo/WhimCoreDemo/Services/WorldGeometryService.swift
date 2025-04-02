import Foundation
import CoreLocation
import WhimCore
import RxSwift
import RxRelay
import GEOSwift
import OrderedCollections

// MARK: - State

extension WorldGeometryService {
    struct State {
        typealias Countries = OrderedDictionary<CountryCode, CountryGeometryInfo>

        struct CountryGeometryInfo: Equatable {
            var name: CountryName
            var coordinate: CLLocationCoordinate2D
            var continent: Continent
            var region: CountryRegion
            var geometry: Geometry
        }

        var countries: DemoLoadingStatus<Countries>

        static let initial: State = .init(countries: .initial)
    }
}

// MARK: - Actions & Events

extension WorldGeometryService {
    enum Action {
        case start
        case reload
    }

    enum Event {
        case action(Action)
        case didFetchCountries(Result<GeoJSON, DemoError>)
    }
}

// MARK: - Reducer

extension WorldGeometryService.State {
    // swiftlint:disable:next superfluous_disable_command cyclomatic_complexity
    static func reduce(state: inout WorldGeometryService.State, event: WorldGeometryService.Event) {
        switch event {
        case .action(.start):
            if state.countries.isIdle {
                state.countries = .loading(nil)
            }

        case .action(.reload):
            state.countries.startLoading()

        case let .didFetchCountries(jsonResult):
            let result = jsonResult.flatMap { json -> Result<Countries, DemoError> in
                guard case let .featureCollection(collection) = json else {
                    return .failure(.geo(.wrongFormat))
                }
                return .success(collection.features.reduce(into: [:]) { acc, feature in
                    if let properties = feature.properties,
                       let geometry = feature.geometry,
                       case let .string(countryName) = properties["name"],
                       case let .string(countryCode) = properties["iso_3166_1_alpha_2_codes"],
                       case let .string(continent) = properties["continent"],
                       case let .string(region) = properties["region"],
                       case let .object(point) = properties["geo_point_2d"],
                       case let .number(lat) = point["lat"], case let .number(lon) = point["lon"]
                    {
                        acc[countryCode] = .init(
                            name: countryName,
                            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            continent: continent,
                            region: region,
                            geometry: geometry
                        )
                    }
                })
            }
            state.countries.finish(with: result)
//            if Bool.random() {
//                if Bool.random() {
//                    state.countries.finish(with: result)
//                } else {
//                    state.countries.finish(with: .success([:]))
//                }
//            } else {
//                state.countries.finish(with: .failure(.geo(.missingResource)))
//            }
        }
    }
}

// MARK: - Service

typealias WorldGeometryServing = AbstractService<WorldGeometryService.State, WorldGeometryService.Action>

final class WorldGeometryService: WorldGeometryServing {
    private let system: FeedbackSystem<State, Event>
    private let actions = PublishRelay<Action>()

    override var state: ObservableProperty<State> {
        system.state
    }

    init(
        scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .userInitiated, internalSerialQueueName: "com.whim.WorldGeometryService")
    ) {
        system = FeedbackSystem(
            initial: .initial,
            scheduler: scheduler,
            reduce: State.reduce,
            feedbacks: [
                .just(effects: actions.map(Event.action)),
                Self.fetchCountries(scheduler: scheduler)
            ]
        )
    }

    override func dispatch(_ action: Action) {
        actions.accept(action)
    }
}

fileprivate extension WorldGeometryService {
     static func fetchCountries(scheduler: SchedulerType) -> Feedback<State, Event> {
         .whenBecomesTrue(state: \.countries.isLoading) { _ in
             // geojson resource taken from: https://public.opendatasoft.com/explore/dataset/country_shapes/information/
             guard let geoURL = Bundle.main.url(forResource: "world", withExtension: "geojson"), let data = try? Data(contentsOf: geoURL) else {
                 return .just(.didFetchCountries(.failure(.geo(.missingResource)))).delay(.seconds(1), scheduler: scheduler)
             }
             let decoder = JSONDecoder()
             guard let geoJSON = try? decoder.decode(GeoJSON.self, from: data) else {
                 return .just(.didFetchCountries(.failure(.geo(.wrongFormat)))).delay(.seconds(1), scheduler: scheduler)
             }
             return .just(.didFetchCountries(.success(geoJSON))).delay(.seconds(1), scheduler: scheduler)
         }
     }
}
