import MapKit
import RxSwift
import RxCocoa

// MARK: - MKMapView

// Didn't want to load whole framework, so I took only needed part from here: https://github.com/RxSwiftCommunity/RxMKMapView

// MARK: Events

extension Reactive where Base: MKMapView {
    var delegate: DelegateProxy<MKMapView, MKMapViewDelegate> {
        return RxMKMapViewDelegateProxy.proxy(for: base)
    }

    var didChangeVisibleRegion: ControlEvent<Void> {
        return ControlEvent(events: delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapViewDidChangeVisibleRegion(_:)))
            .map { _ in }
        )
    }

    var regionDidChangeAnimated: ControlEvent<Bool> {
        return ControlEvent(events: delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapView(_:regionDidChangeAnimated:)))
            .map { a in return try castOrThrow(Bool.self, a[1]) }
        )
    }

    var region: Observable<MKCoordinateRegion> {
        return regionDidChangeAnimated
            .map { [base] _ in base.region }
            .startWith(base.region)
    }

    var zoomLevel: Observable<Double> {
        ControlEvent(events: delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapViewDidChangeVisibleRegion(_:)))
            .map { a in return try castOrThrow(MKMapView.self, a[0]) }
            .map { mapView in mapView.zoomLevel }
        ).startWith(base.zoomLevel)
    }
}

// MARK: Delegate Proxy

extension MKMapView: HasDelegate {
    public typealias Delegate = MKMapViewDelegate
}

final class RxMKMapViewDelegateProxy: DelegateProxy<MKMapView, MKMapViewDelegate>, DelegateProxyType, MKMapViewDelegate {
    weak private(set) var mapView: MKMapView?

    init(mapView: ParentObject) {
        self.mapView = mapView
        super.init(parentObject: mapView, delegateProxy: RxMKMapViewDelegateProxy.self)
    }

    static func registerKnownImplementations() {
        self.register { RxMKMapViewDelegateProxy(mapView: $0) }
    }
}

// MARK: Utils

/// Taken from RxCococa until marked as public
func castOrThrow<T>(_ resultType: T.Type, _ object: Any) throws -> T {
    guard let returnValue = object as? T else {
        throw RxCocoaError.castingError(object: object, targetType: resultType)
    }
    return returnValue
}

// MARK: - MKDirections

extension Reactive where Base: MKDirections {
    func calculate() -> Single<MKDirections.Response> {
        return Single.create { observer -> Disposable in
            base.calculate { response, error in
                if let error = error {
                    observer(.failure(error))
                } else if let response = response {
                    observer(.success(response))
                } else {
                    observer(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil)))
                }
            }
            return Disposables.create {
                base.cancel()
            }
        }
    }
}
