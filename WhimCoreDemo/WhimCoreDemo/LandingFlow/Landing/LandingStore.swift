import Foundation
import WhimCore
import RxSwift
import RxRelay
import OrderedCollections

// MARK: - State

extension LandingStore {
    struct State: Equatable {
        struct CountryInfo: Equatable {
            var name: String
            var flag: String
        }

        struct Map: Equatable {
            var isActive: Bool
            var loadingStyle: MapReloadSidebarItemView.Style

            static let initial: Map = .init(isActive: false, loadingStyle: .normal)
        }

        var map: Map
        var countries: DemoLoadingStatus<OrderedDictionary<String, [CountryInfo]>>

        static let initial: State = .init(map: .initial, countries: .initial)
    }
}

// MARK: - Actions & Events

extension LandingStore {
    enum Action {
        case didBecomeActive(Bool)
        case didTapCloseButton
        case map(LandingMap.Action)
    }

    enum Event {
        case action(Action)
        case didUpdateCountries(DemoLoadingStatus<WorldGeometryService.State.Countries>)
    }
}

// MARK: - Reducer

extension LandingStore.State {
    // swiftlint:disable:next superfluous_disable_command cyclomatic_complexity
    static func reduce(state: inout LandingStore.State, event: LandingStore.Event) {
        switch event {
        case let .action(.didBecomeActive(isActive)):
            state.map.isActive = isActive

        case let .didUpdateCountries(countriesStatus):
            state.countries = countriesStatus.map { countries in
                countries.elements
                    .reduce(into: [:]) { acc, keyValue in
                        let (name, info) = keyValue
                        acc[info.continent, default: []].append(CountryInfo(name: name, code: info.code))
                    }
            }
            state.map.loadingStyle = switch countriesStatus {
                case .idle, .loading: .spinning
                case .loaded: .normal
                case .failed: .highlighted
            }

        case .action(.map(.reloadCountries)):
            break

        case .action(.didTapCloseButton):
            break
        }
    }
}

// MARK: - Store

final class LandingStore: WhimSceneStore {
    private let system: FeedbackSystem<State, Event>
    private let actions = PublishRelay<Action>()

    var state: Observable<State> {
        system.asObservable()
    }

    var routes: Observable<Route> {
        system.eventsWithState.compactMap { [weak self] event, state in
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
        worldGeometryService: WorldGeometryServing
    ) {
        system = FeedbackSystem(
            initial: .initial,
            scheduler: scheduler,
            reduce: State.reduce,
            feedbacks: [
                .just(effects: actions.map(Event.action)),
                Self.updateCountriesStatus(worldGeometryService: worldGeometryService),
                Self.reloadCountries(worldGeometryService: worldGeometryService)
            ]
        )
    }

    func dispatch(_ action: Action) {
        actions.accept(action)
    }
}

fileprivate extension LandingStore {
    static func updateCountriesStatus(worldGeometryService: WorldGeometryServing) -> Feedback<State, Event> {
        .just(
            effects: worldGeometryService.state.asObservable().map(\.countries).map(Event.didUpdateCountries)
        )
    }

    static func reloadCountries(worldGeometryService: WorldGeometryServing) -> Feedback<State, Event> {
        .imperative { [weak worldGeometryService] dispatch in
            return { _, event in
                if case .action(.map(.reloadCountries)) = event {
                    worldGeometryService?.dispatch(.reload)
                }
            }
        }
    }
}

// MARK: - Routes

extension LandingStore {
    enum Route {
        case dismiss
    }
}

// MARK: - Extensions

extension LandingStore.State.CountryInfo {
    var description: String {
        "\(flag) \(name)"
    }

    init(name: WorldGeometryService.State.CountryName, code: WorldGeometryService.State.CountryCode) {
        let baseFlagScalar: UInt32 = 127397
        var flagString = ""
        for scalarValue in code.uppercased().unicodeScalars {
            guard let scalar = UnicodeScalar(baseFlagScalar + scalarValue.value) else {
                continue
            }
            flagString.unicodeScalars.append(scalar)
        }
        self.flag = flagString
        self.name = name
    }
}
