import Foundation
import WhimCore
import RxSwift
import RxRelay
import CoreLocation

// MARK: - State

extension UserLocationService {
    enum State: Equatable {
        case idle
        case starting
        case authorized(LocationDetails?)
        case unauthorized(UnauthorizedReason)

        struct LocationDetails: Equatable {
            var location: CLLocation
            var heading: CLHeading?
        }

        enum UnauthorizedReason: Equatable, CaseIterable {
            case notDetermined, restricted, denied
        }

        static let initial: State = .idle
    }
}

// MARK: - Actions & Events

extension UserLocationService {
    enum Action {
        case start
    }

    enum Event {
        case action(Action)
        case locationManager(LocationManager)

        enum LocationManager {
            case authStatusDidChange(CLAuthorizationStatus)
            case locationDidChange([CLLocation])
            case locationDidFail(CLError)
            case locationHeadingDidChange(CLHeading)
        }
    }
}

// MARK: - Reducer

extension UserLocationService.State {
    // swiftlint:disable:next superfluous_disable_command cyclomatic_complexity
    static func reduce(state: inout UserLocationService.State, event: UserLocationService.Event) {
        switch event {
        case .action(.start):
            if state.isIdle {
                state = .starting
            }

        case let .locationManager(.authStatusDidChange(status)):
            switch status {
            case .notDetermined: state = .unauthorized(.notDetermined)
            case .denied: state = .unauthorized(.denied)
            case .restricted: state = .unauthorized(.restricted)
            case .authorizedAlways: state = .authorized(state.locationDetails)
            case .authorizedWhenInUse: state = .authorized(state.locationDetails)
            @unknown default: return
            }

        case let .locationManager(.locationDidChange(locations)):
            guard let location = locations.last(where: { $0.horizontalAccuracy >= 0 }) else {
                return
            }
            if var details = state.locationDetails {
                details.location = location
                state = .authorized(details)
            } else {
                state = .authorized(.init(location: location, heading: nil))
            }

        case let .locationManager(.locationDidFail(error)):
            if error.code == .denied {
                state = .unauthorized(.denied)
            } else if state.isIdle || state.isStarting {
                state = .unauthorized(.notDetermined)
            }

        case let .locationManager(.locationHeadingDidChange(heading)):
            if var details = state.locationDetails, heading.headingAccuracy >= 0, heading.trueHeading >= 0 {
                details.heading = heading
                state = .authorized(details)
            }
        }
    }
}

// MARK: - Service

typealias UserLocationServing = AbstractService<UserLocationService.State, UserLocationService.Action>

final class UserLocationService: UserLocationServing {
    private let system: FeedbackSystem<State, Event>
    private let actions = PublishRelay<Action>()

    override var state: ObservableProperty<State> {
        return system.state
    }

    init(
        scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .userInitiated, internalSerialQueueName: "com.whim.UserLocationService"),
        locationManager: CLLocationManager = .init(),
        notificationCenter: NotificationCenter = .default
    ) {
        let locationManagerDelegate = LocationManagerDelegate()
        system = FeedbackSystem(
            initial: .initial,
            scheduler: scheduler,
            reduce: State.reduce,
            feedbacks: [
                .just(effects: actions.map(Event.action)),
                .just(effects: locationManagerDelegate.events.map(Event.locationManager)),
                Self.startLocationManager(locationManager: locationManager, delegate: locationManagerDelegate),
            ]
        )
    }

    override func dispatch(_ action: Action) {
        actions.accept(action)
    }
}

fileprivate extension UserLocationService {
    static func startLocationManager(locationManager: CLLocationManager, delegate: LocationManagerDelegate) -> Feedback<State, Event> {
        .whenBecomesTrue(state: \.isStarting, effects: { _ in
            locationManager.delegate = delegate
            locationManager.distanceFilter = 25
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingHeading()
            locationManager.startUpdatingLocation()

            return .empty()
        })
    }
}

fileprivate extension UserLocationService {
    final class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
        private let locationManagerEvents = PublishRelay<Event.LocationManager>()
        var events: Observable<Event.LocationManager> { locationManagerEvents.asObservable() }

        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            locationManagerEvents.accept(.authStatusDidChange(status))
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            locationManagerEvents.accept(.locationDidChange(locations))
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            locationManagerEvents.accept(.locationDidFail(CLError(_nsError: error as NSError)))
        }

        func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
            locationManagerEvents.accept(.locationHeadingDidChange(newHeading))
        }
    }
}

// MARK: - Extensions

extension UserLocationService.State {
    var isIdle: Bool {
        guard case .idle = self else { return false }
        return true
    }
    var isStarting: Bool {
        guard case .starting = self else { return false }
        return true
    }
    var isUnauthorized: Bool {
        guard case .unauthorized = self else { return false }
        return true
    }
    var isAuthorized: Bool {
        guard case .authorized = self else { return false }
        return true
    }
    var isDenied: Bool {
        unauthorizedReason == .denied
    }
    var isRestricted: Bool {
        unauthorizedReason == .restricted
    }
    var isNotDetermined: Bool {
        unauthorizedReason == .notDetermined
    }

    var unauthorizedReason: UnauthorizedReason? {
        guard case let .unauthorized(reason) = self else { return nil }
        return reason
    }
    var locationDetails: LocationDetails? {
        switch self {
        case let .authorized(value): value
        default: nil
        }
    }
}

extension UserLocationServing {
    var userLocationCoordinate: Observable<CLLocationCoordinate2D?> {
        state.asObservable().map(\.locationDetails?.location.coordinate)
    }
}
