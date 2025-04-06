import UIKit
import RxSwift
import RxRelay
import WhimCore

final class HomeViewController: WhimSceneContainerViewController, MapViewControllerDynamicLayoutGuide {
    private lazy var mapViewController: AppleMapsViewController = {
        return AppleMapsViewController(layerManager: ServiceLocator.current.mapLayerManager)
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

    private(set) lazy var mapVerticalInset: ObservableProperty<VerticalInsets> = {
        ObservableProperty(
            initial: .zero,
            then: presentedSceneViewController.asObservable()
                .take(until: rx.deallocated)
                .compactMap(\.self?.multipart)
                .flatMapLatest { [weak mapViewController = self.mapViewController] (top, bottom) -> Observable<VerticalInsets> in
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
                        .observe(on: MainScheduler.asyncInstance)
                        .map { _, stickyPoints in
                            let bottomInset = zip(mapViewController?.view.bounds.height, stickyPoints.last).map(-)
                                ?? bottom.view.bounds.height
                            return VerticalInsets(top: top.view.bounds.height, bottom: bottomInset)
                        }
                }
                // hack to solve the issue of racing between map layer becoming active and screen appearing
                .delay(.milliseconds(50), scheduler: MainScheduler.asyncInstance)
        )
    }()

    private(set) lazy var mapSidebarBottomInset: ObservableProperty<CGFloat> = {
        ObservableProperty(
            initial: .zero,
            then: presentedSceneViewController.asObservable()
                .take(until:rx.deallocated)
                .compactMap(\.self?.multipart)
                .flatMapLatest { [weak mapViewController = self.mapViewController] (_, bottom) -> Observable<CGFloat> in
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
                            mapViewController.map { $0.view.bounds.height - position } ?? bottom.view.bounds.height
                        }
                }
        )
    }()

    private let flow: HomeFlow

    init(flow: HomeFlow) {
        self.flow = flow
        super.init(initial: flow.stack)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var sceneContainerView: UIView {
        flowContainer
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        embed(viewController: mapViewController, inView: mapContainer)
        mapViewController.dynamicLayoutGuide = self

        flow.dispatch(.didLoad)
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

private extension HomeViewController {
    func embed(viewController: UIViewController, inView containerView: UIView) {
        addChild(viewController)
        containerView.embed(view: viewController.view)
        viewController.didMove(toParent: self)
    }
}
