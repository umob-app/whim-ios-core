import Foundation
import RxSwift

// MARK: - Layer Token

/// Unique layer identifier.
///
/// Can be compared and hashed.
/// Associated with a layer at its initilazation step.
public struct MapLayerToken: Hashable {
    private let rawValue: UUID

    fileprivate init() {
        rawValue = UUID()
    }
}

// MARK: - Layer Lifetime

/// Represent map layer lifetime.
///
/// Can be ended at any arbitrary time.
/// Will be disposed of if not retained by anyone.
public final class MapLayerLifetime: Cancelable {
    private let cancelable: Cancelable

    public var isDisposed: Bool {
        return cancelable.isDisposed
    }

    fileprivate init(_ action: @escaping () -> Void) {
        cancelable = Disposables.create(with: action)
    }

    public func dispose() {
        cancelable.dispose()
    }

    deinit {
        dispose()
    }
}

// MARK: - Layer Initial State

// sourcery: Random
/// Lists properties that can be transferred from previous layer to the new layer.
/// If there's no previous layer, will use default or whatever new layer has without changing it.
public struct InterLayerProps {
    // sourcery: Random
    public enum Options: Int, Option, CaseIterable {
        // TODO: MAP `markers, overlays` - temporary disabled until AppleMapsViewController is unit-tested and can be safely extended
        case configs, sidebar, clustering, userTracking
    }

    /// We can transfer either one of the chose positions, or none at all if we want new layer to set its own.
    public let position: Animatable<MapLayerVisibleRectInset.Position>?
    public let options: Set<Options>

    public init(position: Animatable<MapLayerVisibleRectInset.Position>?, options: Set<Options> = []) {
        self.position = position
        self.options = options
    }

    public init(position: MapLayerVisibleRectInset.Position?, options: Set<Options> = [], animated: Bool = false) {
        self.init(position: position.map { Animatable($0, animated: animated) }, options: options)
    }

    public static var none: InterLayerProps {
        return InterLayerProps(position: .none, options: [])
    }
}

// MARK: - Delegate

protocol MapLayerManagerDelegate: AnyObject {
    associatedtype Context

    func mapLayerManager(_ manager: MapLayerManager<Context>, didActivateLayerWithToken token: MapLayerToken, initialState state: MapLayerState, initialPosition: MapLayerVisibleRectInset.Position?)
    func mapLayerManager(_ manager: MapLayerManager<Context>, didUpdateState state: MapLayerState, forLayerWithToken token: MapLayerToken)
    func mapLayerManager(_ manager: MapLayerManager<Context>, didRelinquishActiveLayerWithToken token: MapLayerToken)
}

/// A type erasure thunk for wrapping map layer manger delegate.
/// It weakifies the delegate itself here.
///
/// More about type erasure and why it's needed here: https://krakendev.io/blog/generic-protocols-and-their-shortcomings
final class AnyMapLayerManagerDelegate<Context>: MapLayerManagerDelegate {
    private let didActivateLayerWithToken: (_ manager: MapLayerManager<Context>, _ token: MapLayerToken, _ state: MapLayerState, _ initialPosition: MapLayerVisibleRectInset.Position?) -> Void
    private let didUpdateState: (_ manager: MapLayerManager<Context>, _ state: MapLayerState, _ token: MapLayerToken) -> Void
    private let didRelinquishActiveLayerWithToken: (_ manager: MapLayerManager<Context>, _ token: MapLayerToken) -> Void

    init<Delegate: MapLayerManagerDelegate>(_ delegate: Delegate) where Delegate.Context == Context {
        didActivateLayerWithToken = { [weak delegate] manager, token, state, initialPosition in
            delegate?.mapLayerManager(manager, didActivateLayerWithToken: token, initialState: state, initialPosition: initialPosition)
        }
        didUpdateState = { [weak delegate] manager, state, token in
            delegate?.mapLayerManager(manager, didUpdateState: state, forLayerWithToken: token)
        }
        didRelinquishActiveLayerWithToken = { [weak delegate] manager, token in
            delegate?.mapLayerManager(manager, didRelinquishActiveLayerWithToken: token)
        }
    }

    func mapLayerManager(_ manager: MapLayerManager<Context>, didActivateLayerWithToken token: MapLayerToken, initialState state: MapLayerState, initialPosition: MapLayerVisibleRectInset.Position?) {
        didActivateLayerWithToken(manager, token, state, initialPosition)
    }

    func mapLayerManager(_ manager: MapLayerManager<Context>, didUpdateState state: MapLayerState, forLayerWithToken token: MapLayerToken) {
        didUpdateState(manager, state, token)
    }

    func mapLayerManager(_ manager: MapLayerManager<Context>, didRelinquishActiveLayerWithToken token: MapLayerToken) {
        didRelinquishActiveLayerWithToken(manager, token)
    }
}

// MARK: - Manager

/// Manages multiple map layers that are responsible for interacting with the actual map.
///
/// It receives events from the map view, decides which layer should receive them,
/// and delegates active layers' updates back to the map.
///
/// Example:
///
/// 1. First, you need to register new layer in the system. It doesn't become active right away.
///    So you can register as much layers as you want without affecting the actual map view.
///
///    You receive a layer and its lifetime as a result of a new registry.
///
/// 2. You'd usually operate with token to request or relinquish control for the corresponding layer.
///
///    Requesting control makes your layer active, and relinquishes previous layers.
///    Once layer is active, it's connected with the map view. Layer data is drawn on the map right away,
///    and all the event from user interaction or other map changes are transmitted to the currently active layer.
///
///    There can be only once active layer at a time.
///
///    Relinquishing layer doesn't remove it from the system, but makes it idle.
///    Thus, inactive layers won't receive any events from the map and any changes to the layer won't be applied to the map,
///    until layer regains control again.
///
/// 3. To completely remove map layer from the system, use its lifetime.
///    Layer will be removed if there're no strong references to its lifetime, or when its lifetime was ended on purpose.
///    Manager doesn't retain layers' lifetime objects, so you should retain it yourself.
///    Or if you already have a `DisposeBag`, you can associate lifetime object with it.
///
///    This way, you don't have to manually clean it up and layer will be always removed once its client dies.
///
/// - Important: `MapLayerManager` should be used only on Main thread.
///
/// - Note: Uber has also solved similar problem, but in a more complex way.
///         [More here.](https://eng.uber.com/building-a-scalable-and-reliable-map-interface-for-drivers/)

public final class MapLayerManager<Context> {
    /// A delegate to dispatch some events to.
    /// This thunk is not weakified here because it weakifies original delegate underneath when wrapping it.
    var delegate: AnyMapLayerManagerDelegate<Context>? {
        didSet {
            if let activeLayer = activeLayer {
                delegate?.mapLayerManager(self, didUpdateState: activeLayer.state, forLayerWithToken: activeLayer.token)
            }
        }
    }

    private var layers: [MapLayerToken: MapLayer<Context>] = [:]
    private var activeLayerToken: MapLayerToken? {
        willSet { activeLayer?.didBecomeActive(false) }
        didSet { activeLayer?.didBecomeActive(true) }
    }
    private var activeLayer: MapLayer<Context>? {
        return activeLayerToken.flatMap { layers[$0] }
    }

    public init() {}

    /// Creates new layer but doesn't activate it yet.
    /// - Parameter context: optional data to associate with the layer in the current context.
    /// - Returns:
    ///   - layer: new map layer with default state.
    ///   - lifetime: layer's lifetime to allow completely removing layer from the map.
    /// - Note: Lifetime is not retained by the manager. Layer will be removed once lifetime isn't retained by anyone.
    public func registerNewLayer(with context: Context? = nil) -> (layer: MapLayer<Context>, lifetime: MapLayerLifetime) {
        var token: MapLayerToken
        repeat {
            token = MapLayerToken()
        } while layers[token] != nil

        let layer = MapLayer<Context>(
            token: token,
            context: context,
            stateObserver: { [weak self] state in
                self?.mapLayer(with: token, didUpdateState: state)
            }
        )
        layers[token] = layer
        let lifetime = MapLayerLifetime { [weak self] in
            guard let self = self else { return }
            self.relinquishControlForLayer(with: token)
            self.layers.removeValue(forKey: token)
        }
        return (layer, lifetime)
    }

    private func mapLayer(with token: MapLayerToken, didUpdateState state: MapLayerState) {
        guard activeLayerToken == token else {
            return
        }
        delegate?.mapLayerManager(self, didUpdateState: state, forLayerWithToken: token)
    }

    /// Tells whether layer with given token is stored inside.
    public func hasLayer(with token: MapLayerToken) -> Bool {
        return layers[token] != nil
    }

    /// Tells whether layer with given token is active or not.
    public func isLayerActive(with token: MapLayerToken) -> Bool {
        return activeLayerToken == token
    }

    /// Makes layer active if it's registered in this manager.
    /// - Parameters:
    ///   - token: token of a layer that should become active and responsible for rendering data and interacting with the map.
    ///   - transferSchema: properties to transfer from previous active layer, if there's such.
    ///                     If position given here differs from position in layer's visibleRectInset property,
    ///                     this one will be used only for the first time after layer becomes active,
    ///                     and all the next times layer's visibleRectInset property will be used as expected.
    /// - Returns:
    ///   - `true` if such layer exists in the system and was successfully activated.
    ///   - `false` if there's no layer associated with the token.
    @discardableResult
    public func requestControlForLayer(
        with token: MapLayerToken,
        transferFromPrevLayer transferSchema: (Context?) -> InterLayerProps
    ) -> Bool {
        guard activeLayerToken != token else {
            return true
        }
        guard let layer = layers[token] else {
            return false
        }
        var initialPosition: MapLayerVisibleRectInset.Position? = nil
        if let previousLayer = activeLayer {
            let transferProps = transferSchema(previousLayer.context)
            if transferProps.options.contains(.configs) {
                layer.configs = previousLayer.configs
            }
            if let transferPosition = transferProps.position {
                let animated = transferPosition.animated
                initialPosition = transferPosition.value
                switch transferPosition.value {
                case .absolute:
                    layer.setHeading(previousLayer.heading, animated: animated)
                    layer.setCenter(MapLayerState.defaultCenterCoordinate, zoomLevel: previousLayer.zoomLevel, animated: animated)
                    layer.setTrackingUser(false, animated: animated)
                case .relative:
                    layer.setHeading(previousLayer.heading, animated: animated)
                    layer.setCenter(previousLayer.centerCoordinate, zoomLevel: previousLayer.zoomLevel, animated: animated)
                case .coordinateOnly:
                    layer.setHeading(layer.heading, animated: animated)
                    layer.setCenter(previousLayer.centerCoordinate, zoomLevel: layer.zoomLevel, animated: animated)
                }
            }
            if transferProps.options.contains(.sidebar) {
                layer.sidebar = previousLayer.sidebar
            }
// TODO: MAP `markers, overlays` - temporary disabled until AppleMapsViewController is unit-tested and can be safely extended
//            if transferProps.contains(.markers) {
//                layer.markers = previousLayer.markers
//            }
//            if transferProps.contains(.overlays) {
//                layer.overlays = previousLayer.overlays
//            }
            if transferProps.options.contains(.clustering) {
                layer.clusterMarkerProvider = previousLayer.clusterMarkerProvider
                layer.clusterConfigsProvider = previousLayer.clusterConfigsProvider
            }
            if transferProps.options.contains(.userTracking) {
                layer.isTrackingUser = previousLayer.isTrackingUser
            }
        }
        activeLayerToken = token
        delegate?.mapLayerManager(self, didActivateLayerWithToken: layer.token, initialState: layer.state, initialPosition: initialPosition)
        return true
    }

    /// - Returns:
    ///   - `true` if such layer exists in the system and was successfully deactivated.
    ///   - `false` if there's no layer associated with the token.
    @discardableResult
    public func relinquishControlForLayer(with token: MapLayerToken) -> Bool {
        guard layers[token] != nil else {
            return false
        }
        guard token == activeLayerToken else {
            return true
        }
        activeLayerToken = nil
        delegate?.mapLayerManager(self, didRelinquishActiveLayerWithToken: token)
        return true
    }

    /// Sends an event to a layer with a given token.
    /// Will send the event only if the layer is active at the moment.
    ///
    /// It's debatable whether to allow sending event to inactive layer or not.
    /// However there's a real-world case which suggests to not allow propagating events to inactive layer:
    /// When layer is deactivated, all of its markers are removed from the map, which causes MKMapView to deselect them.
    /// And if we let manager to deliver this (deselection) event to inactive layer, its selected marker will become deselected,
    /// which might be not something expected.
    /// A more predictable behavior would be to leave whole layer state untouched as it was at the moment when it was deactivated.
    func handle(event: MapEvent, for token: MapLayerToken?) {
        guard let token = token, activeLayerToken == token else {
            return
        }
        layers[token]?.handle(event: event)
    }
}

extension MapLayerManager {
    @discardableResult
    public func requestControlForLayer(
        with token: MapLayerToken,
        transferFromPrevLayer transferProps: InterLayerProps = .init(position: .absolute, options: [.userTracking], animated: false)
    ) -> Bool {
        requestControlForLayer(with: token, transferFromPrevLayer: { _ in transferProps })
    }
}

// MARK: - Testing

#if DEBUG

internal extension MapLayerManager {
    static func testLayer(context: Context? = nil, stateObserver: @escaping MapLayer<Context>.StateObserver) -> MapLayer<Context> {
        MapLayer(token: MapLayerToken(), context: context, stateObserver: stateObserver)
    }
}

#endif
