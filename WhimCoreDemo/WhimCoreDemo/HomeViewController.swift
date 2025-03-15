import UIKit
import RxSwift
import RxRelay
import WhimCore

public enum WhimDemoMap {
    case initial
}

public let mapLayerManager = MapLayerManager<WhimDemoMap>()

public final class WhimViewController: WhimSceneContainerViewController, MapViewControllerDynamicLayoutGuide {
    private lazy var mapViewController: AppleMapsViewController = {
        return AppleMapsViewController(layerManager: mapLayerManager)
    }()

    private lazy var mapContainer: UIView = {
        let containerView = UIView()
        view.embed(view: containerView)
        view.sendSubviewToBack(containerView)
        return containerView
    }()

    private lazy var flowContainer: UIView = {
        let containerView = PassthroughView()
        view.embed(view: containerView)
        view.bringSubviewToFront(containerView)
        return containerView
    }()

    public private(set) lazy var mapVerticalInset: ObservableProperty<VerticalInsets> = {
        ObservableProperty(
            initial: .zero,
            then: presentedSceneViewController.asObservable().flatMapLatest { [weak mapViewController = self.mapViewController] presentedScene -> Observable<VerticalInsets> in
                guard case let .multipart(top, bottom) = presentedScene else {
                    return .empty()
                }
                guard let bottomPanel = bottom as? BottomPanel else {
                    return bottom.rx.viewDidAppear
                        .take(until: bottom.rx.viewDidDisappear)
                        .map { _ in VerticalInsets(top: top.view.bounds.height, bottom: bottom.view.bounds.height) }
                }
                let bottomPanelStickyPoints = bottomPanel.bottomPanelHandler.asObservable().compactMap { event -> [CGFloat]? in
                    guard case let .didRefreshStickyPoints(points) = event else { return nil }
                    return points.map(\.absolute.value)
                }
                return Observable.combineLatest(bottom.rx.viewDidAppear, bottomPanelStickyPoints)
                    .take(until: bottom.rx.viewDidDisappear)
                    .map { _, stickyPoints in
                        let bottomInset = zip(mapViewController?.view.bounds.height, stickyPoints.last).map(-)
                            ?? bottom.view.bounds.height
                        return VerticalInsets(top: top.view.bounds.height, bottom: bottomInset)
                    }
            }
        )
    }()

    public private(set) lazy var mapSidebarBottomInset: ObservableProperty<CGFloat> = {
        ObservableProperty(
            initial: .zero,
            then: presentedSceneViewController.asObservable().flatMapLatest { [weak mapViewController = self.mapViewController] presentedScene -> Observable<CGFloat> in
                guard case let .multipart(_, bottom) = presentedScene else {
                    return .empty()
                }
                guard let bottomPanel = bottom as? BottomPanel else {
                    return bottom.rx.viewDidAppear.take(until: bottom.rx.viewDidDisappear).map { _ in bottom.view.bounds.height }
                }
                let bottomPanelPositions = bottomPanel.bottomPanelHandler.asObservable().compactMap { event -> CGFloat? in
                    switch event {
                    case .didDrag(let point), .didMove(let point, _): return point.absolute.value
                    case .didRefreshStickyPoints: return nil
                    }
                }
                return Observable.combineLatest(bottom.rx.viewDidAppear, bottomPanelPositions.distinctUntilChanged())
                    .take(until: bottom.rx.viewDidDisappear)
                    .map { _, position in
                        return mapViewController.map { $0.view.bounds.height - position } ?? bottom.view.bounds.height
                    }
            }
        )
    }()

    public override var sceneContainerView: UIView {
        return flowContainer
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        embed(viewController: mapViewController, inView: mapContainer)
        mapViewController.dynamicLayoutGuide = self
//        self.view.backgroundColor = .systemPink
    }

    deinit {
        print("☠️ 🏡")
    }
}

// MARK: - UI Helpers

private extension UIView {
    func embed(view: UIView) {
        guard view.superview == nil else {
            return
        }
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

private extension WhimViewController {
    func embed(viewController: UIViewController, inView containerView: UIView) {
        addChild(viewController)
        containerView.embed(view: viewController.view)
        viewController.didMove(toParent: self)
    }
}

func zip<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    return a.flatMap { a in b.map { b in (a, b) } }
}
