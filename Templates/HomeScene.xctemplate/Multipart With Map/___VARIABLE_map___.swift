//___FILEHEADER___

import CoreLocation
import WhimCore
import RxSwift

final class ___VARIABLE_map:identifier___: ScenePresentation {
    typealias State = ___VARIABLE_store:identifier___.State.Map

    enum Action {
    }

    var output: ___VARIABLE_map:identifier___.Dispatch?

    private let mapLayerManager: HomeMapLayerManager
    private let map: (layer: HomeMapLayer, lifetime: MapLayerLifetime)

    private var isActive: Bool = false

    init(mapLayerManager: HomeMapLayerManager) {
        self.mapLayerManager = mapLayerManager
        self.map = mapLayerManager.registerNewLayer()

        setupMapLayer()
    }

    private func setupMapLayer() {
        // Config map layer and bind to its events here
    }

    func render(state: State) {
        // Perform map rendering here

        applyActiveState(state.isActive)
    }

    private func applyActiveState(_ isActive: Bool) {
        guard isActive != self.isActive else {
            return
        }
        if isActive {
            mapLayerManager.requestControlForLayer(with: map.layer.token)
        } else {
            mapLayerManager.relinquishControlForLayer(with: map.layer.token)
        }
        self.isActive = isActive
    }
}
