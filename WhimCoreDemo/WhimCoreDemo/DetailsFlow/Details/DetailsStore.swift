import Foundation
import WhimCore
import RxSwift
import RxRelay
import GEOSwift
import CoreLocation

// MARK: - State

extension DetailsStore {
    struct State: Equatable {
        struct CountryInfo: Equatable {
            var name: CountryName
            var region: CountryRegion
            var flag: String
            var coordinate: CLLocationCoordinate2D
            var geometry: Geometry
        }

        struct Map: Equatable {
            var isActive: Bool
            var country: DemoLoadingStatus<CountryInfo>
            var visibleCoordinate: CLLocationCoordinate2D?

            static let initial: Map = .init(isActive: false, country: .initial)
        }

        var map: Map
        var countryCode: CountryCode

        static func initial(countryCode: CountryCode) -> State {
            .init(map: .initial, countryCode: countryCode)
        }
    }
}

// MARK: - Actions & Events

extension DetailsStore {
    enum Action {
        case didBecomeActive(Bool)
        case didTapCloseButton
        case didTapOnCountryInfo
        case map(DetailsMap.Action)
    }

    enum Event {
        case action(Action)
        case didUpdateCountries(DemoLoadingStatus<WorldGeometryService.State.Countries>)
    }
}

// MARK: - Reducer

extension DetailsStore.State {
    // swiftlint:disable:next superfluous_disable_command cyclomatic_complexity
    static func reduce(state: inout DetailsStore.State, event: DetailsStore.Event) {
        switch event {
        case let .action(.didBecomeActive(isActive)):
            state.map.isActive = isActive

        case let .didUpdateCountries(countriesStatus):
            let countryStatus = countriesStatus.compactMap { countries in
                countries[state.countryCode].map {
                    CountryInfo(
                        name: $0.name,
                        region: $0.region,
                        flag: countryFlag(from: state.countryCode),
                        coordinate: $0.coordinate,
                        geometry: $0.geometry
                    )
                }
            }
            if let countryStatus {
                state.map.country = countryStatus
            } else {
                state.map.country.finish(with: .failure(.geo(.dataUnavailable)))
            }

        case .action(.didTapOnCountryInfo):
            state.map.visibleCoordinate = state.map.country.value?.coordinate

        case let .action(.map(.didUpdateVisibleCoordinate(coordinate))):
            state.map.visibleCoordinate = coordinate

        case .action(.didTapCloseButton):
            break
        }
    }
}

// MARK: - Store

final class DetailsStore: WhimSceneStore {
    private let system: FeedbackSystem<State, Event>
    private let actions = PublishRelay<Action>()

    var state: Observable<State> {
        system.asObservable()
    }

    var routes: Observable<Route> {
        return system.eventsWithState.compactMap { [weak self] event, state in
            switch event {
            case .action(.didTapCloseButton):
                return .dismiss

            default:
                return nil
            }
        }
    }

    init(
        scheduler: SchedulerType = MainScheduler.instance,
        countryCode: CountryCode,
        worldGeometryService: WorldGeometryServing
    ) {
        system = FeedbackSystem(
            initial: .initial(countryCode: countryCode),
            scheduler: scheduler,
            reduce: State.reduce,
            feedbacks: [
                .just(effects: actions.map(Event.action)),
                Self.updateCountriesStatus(worldGeometryService: worldGeometryService),
            ]
        )
    }

    func dispatch(_ action: Action) {
        actions.accept(action)
    }
}

fileprivate extension DetailsStore {
    static func updateCountriesStatus(worldGeometryService: WorldGeometryServing) -> Feedback<State, Event> {
        .just(
            effects: worldGeometryService.state.asObservable().map(\.countries).map(Event.didUpdateCountries)
        )
    }
}

// MARK: - Routes

extension DetailsStore {
    enum Route {
        case dismiss
    }
}
