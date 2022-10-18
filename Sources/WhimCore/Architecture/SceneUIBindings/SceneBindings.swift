import UIKit
import RxSwift

// MARK: - Fullscreen

public extension SceneStore {
    /// A helper method to connect `SceneStore` with fullscreen `ScenePresentation`.
    ///
    /// It subscribes UI to the state updates, and allows UI to dispatch actions into the store.
    /// UI here retains a reference to the store, so once UI is removed from the hierarchy,
    /// store will be also released and all their subscriptions as well.
    /// You may also transfrom BLL state into UI state and UI actions into BLL actions if needed.
    func bind<R: ScenePresentationViewController>(
        fullscreen: SceneBinding<Self, R>,
        router: @escaping (Route) -> Void
    ) {
        let transform = (state: fullscreen.state, action: fullscreen.action)

        _ = Observable.combineLatest(fullscreen.presentation.rx.viewDidLoad, self.state) { _, state in state }
            .observe(on: MainScheduler.instance)
            .take(until: fullscreen.presentation.rx.deallocated)
            .subscribe(onNext: { [weak fullscreen = fullscreen.presentation] in
                if let state = transform.state($0) {
                    fullscreen?.render(state: state)
                }
            })

        _ = routes
            .observe(on: MainScheduler.instance)
            .take(until: fullscreen.presentation.rx.deallocated)
            .subscribe(onNext: router)

        fullscreen.presentation.output = {
            if let action = transform.action($0) {
                self.dispatch(action)
            }
        }
    }
}

// MARK: - Top + Bottom + Map

public extension SceneStore {
    /// A helper method to connect `SceneStore` with multipart `ScenePresentation`.
    ///
    /// It subscribes UIs to the state updates, and allows UIs to dispatch actions into the store.
    /// UIs here retain a reference to the store, so once both UIs are removed from the hierarchy,
    /// store will be also released and all their subscriptions as well.
    /// You may also transfrom BLL state into UIs states and UIs actions into BLL actions if needed.
    func bind<T: ScenePresentationViewController, B: ScenePresentationViewController, M: ScenePresentation>(
        top: SceneBinding<Self, T>,
        bottom: SceneBinding<Self, B>,
        map: SceneBinding<Self, M>,
        router: @escaping (Route) -> Void
    ) {
        let transformTop = (state: top.state, action: top.action)
        let transformBottom = (state: bottom.state, action: bottom.action)
        let transformMap = (state: map.state, action: map.action)
        let mapPresentation = map.presentation
        let sceneDeallocated = Observable.combineLatest(top.presentation.rx.deallocated, bottom.presentation.rx.deallocated)

        _ = Observable.combineLatest(top.presentation.rx.viewDidLoad, bottom.presentation.rx.viewDidLoad, state) { _, _, s in s }
            .observe(on: MainScheduler.instance)
            .take(until: sceneDeallocated)
            .subscribe(onNext: { [weak top = top.presentation, weak bottom = bottom.presentation] in
                if let topState = transformTop.state($0) {
                    top?.render(state: topState)
                }
                if let bottomState = transformBottom.state($0) {
                    bottom?.render(state: bottomState)
                }
                // map binding is a bit different, since no-one holds a reference to it, we need to capture the map here.
                if let mapState = transformMap.state($0) {
                    mapPresentation.render(state: mapState)
                }
            })

        _ = routes
            .observe(on: MainScheduler.instance)
            .take(until: sceneDeallocated)
            .subscribe(onNext: router)

        // capturing store here by top and bottom view-controllers
        top.presentation.output = {
            if let action = transformTop.action($0) {
                self.dispatch(action)
            }
        }
        bottom.presentation.output = {
            if let action = transformBottom.action($0) {
                self.dispatch(action)
            }
        }
        // since we've already captured map in a state-observable closure, we need to weakify reference to the store here.
        map.presentation.output = { [weak self] in
            if let action = transformMap.action($0) {
                self?.dispatch(action)
            }
        }
    }
}

// MARK: - No Routing

public extension SceneStore where Route == Never {
    func bind<P: ScenePresentationViewController>(fullscreen: SceneBinding<Self, P>) {
        bind(fullscreen: fullscreen, router: { _ in })
    }

    func bind<T: ScenePresentationViewController, B: ScenePresentationViewController, M: ScenePresentation>(
        top: SceneBinding<Self, T>,
        bottom: SceneBinding<Self, B>,
        map: SceneBinding<Self, M>
    ) {
        bind(top: top, bottom: bottom, map: map, router: { _ in })
    }
}

// MARK: - Binding

/// A union of transformation rules for state and actions.
///
/// Usually UI has its own view-state for the sake of reusablity and isolation from BLL or network models.
/// That's why you might need to transform BLL-state into UI-state.
///
/// In case of actions transformation - it can be handy, when you work with a multipart scene where each scene has its own action.
/// In this case `action` transformer will map top and bottom actions into single store action.
///
/// You may also find it helpful when a single UI component is reused within multiple scenes, each with its own store.
/// In this case you may also need to transform this component's actions into each scene's store action.
public struct SceneBinding<S: SceneStore, P: ScenePresentation> {
    public let presentation: P
    public let state: (S.State) -> P.State?
    public let action: (P.Action) -> S.Action?

    public init(presentation: P, state: @escaping (S.State) -> P.State?, action: @escaping (P.Action) -> S.Action?) {
        self.presentation = presentation
        self.state = state
        self.action = action
    }
}

public extension SceneBinding where S.State == P.State {
    init(presentation: P, action: @escaping (P.Action) -> S.Action?) {
        self.init(presentation: presentation, state: { $0 }, action: action)
    }
}

public extension SceneBinding where S.Action == P.Action {
    init(presentation: P, state: @escaping (S.State) -> P.State?) {
        self.init(presentation: presentation, state: state, action: { $0 })
    }
}

public extension SceneBinding where S.State == P.State, S.Action == P.Action {
    init(presentation: P) {
        self.init(presentation: presentation, state: { $0 }, action: { $0 })
    }
}

// MARK: - None

public extension SceneBinding {
    /// You might need this in case you don't want any presentation (i.e. Map).
    static var none: SceneBinding<S, NonePresentation> {
        SceneBinding<S, NonePresentation>(presentation: NonePresentation(), state: { _ in nil }, action: { _ in nil })
    }
}

public final class NonePresentation: ScenePresentation {
    public typealias State = Never
    public typealias Action = Never

    public var output: NonePresentation.Dispatch?

    public func render(state: State) {}

    fileprivate init() {}
}
