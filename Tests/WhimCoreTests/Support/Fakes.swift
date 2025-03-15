import Foundation
import SwiftyMock
import CoreLocation
import RxSwift
import RxTest

@testable import WhimCore

final class FakeMapLayerManagerDelegate<Context>: MapLayerManagerDelegate {
    let didActivateLayerWithTokenCall = FunctionCall<(manager: MapLayerManager<Context>, token: MapLayerToken, initialState: MapLayerState, initialPosition: MapLayerVisibleRectInset.Position?), Void>()
    func mapLayerManager(_ manager: MapLayerManager<Context>, didActivateLayerWithToken token: MapLayerToken, initialState state: MapLayerState, initialPosition: MapLayerVisibleRectInset.Position?) {
        stubCall(didActivateLayerWithTokenCall, argument: (manager, token, state, initialPosition: initialPosition), defaultValue: ())
    }

    let didUpdateStateCall = FunctionCall<(manager: MapLayerManager<Context>, state: MapLayerState, token: MapLayerToken), Void>()
    func mapLayerManager(_ manager: MapLayerManager<Context>, didUpdateState state: MapLayerState, forLayerWithToken token: MapLayerToken) {
        stubCall(didUpdateStateCall, argument: (manager, state, token), defaultValue: ())
    }

    let didRelinquishActiveLayerCall = FunctionCall<(manager: MapLayerManager<Context>, token: MapLayerToken), Void>()
    func mapLayerManager(_ manager: MapLayerManager<Context>, didRelinquishActiveLayerWithToken token: MapLayerToken) {
        stubCall(didRelinquishActiveLayerCall, argument: (manager, token), defaultValue: ())
    }
}

final class FakeSceneNavigationStack: WhimSceneNavigationStack {
    let presentCall = FunctionCall<(scene: WhimScene, animating: WhimSceneAnimatedTransitioning?), Void>()
    override func present(scene: WhimScene, animating: WhimSceneAnimatedTransitioning?) {
        stubCall(presentCall, argument: (scene, animating), defaultValue: ())
    }
}
