import UIKit
import CoreLocation
import WhimCore
import RxSwift

final class LandingMap: WhimScenePresentation {
    typealias State = LandingStore.State.Map

    enum Action {
        case reloadCountries
    }

    var output: LandingMap.Dispatch?

    private let disposeBag = DisposeBag()
    private let mapLayerManager: DemoMapLayerManager
    private let map: (layer: DemoMapLayer, lifetime: MapLayerLifetime)

    private var isActive: Bool = false

    init(mapLayerManager: DemoMapLayerManager) {
        self.mapLayerManager = mapLayerManager
        self.map = mapLayerManager.registerNewLayer(with: .landing)

        setupMapLayer()
    }

    private func setupMapLayer() {
        map.layer.sidebar = [
            .trackUser(highlightedContent: nil, normalContent: nil),
            .reloadNormal(highlightColor: .systemBlue, normalTintColor: .systemBlue),
            .filter(isHighlighted: true)
        ]

        map.layer.events.compactMap(\.map?.didTapSidebarItem?.reload)
            .subscribe(onNext: { [weak self] _ in
                self?.dispatch(.reloadCountries)
            })
            .disposed(by: disposeBag)
    }

    func render(state: State) {
        applyActiveState(state.isActive)
        applyLoadingStyle(state.loadingStyle)
    }

    private func applyLoadingStyle(_ loadingStyle: MapReloadSidebarItemView.Style) {
        map.layer.sidebar.compactMap(\.reload).first?.style = loadingStyle
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
