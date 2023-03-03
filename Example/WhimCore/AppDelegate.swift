import UIKit
import MapKit
import CoreLocation
import WhimCore
import WhimUtils
import RxSwift

/* Some Tips:

- Create your new scene:
  ```
  let yourScene = HomeSingleScene(
      top: UIViewController(),
      bottom: UIViewController()
  )
  ```

- Change home scene by setting new root scene, with(-out) one of the provided (or custom) animations:
  ```
  home.set(root: yourScene, animating: HomeSceneAnimatedTransitions.Fade())
  ```

- Create navigation stack with `yourScene` as its root scene, and present it on `home`:
  ```
  let nav = HomeSceneNavigationStack(yourScene)
  home.set(root: nav)
  nav.push(scene: yourNextScene)
  ```
*/

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var map: MapLayer<MaasHomeMap>!
    var mapLifetime: MapLayerLifetime!

    private let disposeBag = DisposeBag()

    private let locationManager = CLLocationManager()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow()

        (map, mapLifetime) = mapLayerManager.registerNewLayer()

        let rootScene = HomeSingleScene(
            top: InitialSceneTopBar(),
            bottom: InitialSceneBottomSheet()
        )
        let initial = HomeSceneNavigationStack(rootScene)
//        let initial = testModalTransitions()
        let home = HomeViewController(initial: initial)

        window.rootViewController = home
        self.window = window
        window.makeKeyAndVisible()

        locationManager.requestWhenInUseAuthorization()

        self.testMap()

        // Uncomment next lines to see how absolute position is applied

//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//            let nextMap = mapLayerManager.registerNewLayer()
//            nextMap.layer.setTrackingUser(false)
//            initial.push(scene: HomeSingleScene(top: InitialSceneTopBar(), bottom: NextSceneBottomSheet()))
//            mapLayerManager.requestControlForLayer(with: nextMap.layer.token, transferFromPrevLayer: .init(position: .absolute, options: [.configs]))
//        }
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
//            initial.popToRoot()
//            mapLayerManager.requestControlForLayer(with: self.map.token, transferFromPrevLayer: .init(position: .absolute, options: []))
//        }

        return true
    }

    private func testModalTransitions() -> HomeScene {
        let fullscreenTo = HomeSingleScene(fullscreen: UIViewController())
        let fullscreenFrom = HomeSingleScene(fullscreen: UIViewController())

        let multipartTo = HomeSingleScene(top: UIViewController(), bottom: UIViewController())
        let multipartFrom = HomeSingleScene(top: UIViewController(), bottom: UIViewController())

        fullscreenFrom.viewController.viewControllers.first?.view.backgroundColor = .blue
        multipartFrom.viewController.viewControllers.first?.view.backgroundColor = .purple
        multipartFrom.viewController.viewControllers.last?.view.backgroundColor = .blue
        multipartFrom.viewController.viewControllers.forEach {
            $0.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([$0.view.heightAnchor.constraint(equalToConstant: 100)])
        }

        fullscreenTo.viewController.viewControllers.first?.view.backgroundColor = .yellow
        multipartTo.viewController.viewControllers.first?.view.backgroundColor = .yellow
        multipartTo.viewController.viewControllers.last?.view.backgroundColor = .green
        multipartTo.viewController.viewControllers.forEach {
            $0.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([$0.view.heightAnchor.constraint(equalToConstant: 100)])
        }

//        let nav = HomeSceneNavigationStack(fullscreenFrom)
        let nav = HomeSceneNavigationStack(multipartFrom)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            nav.push(scene: multipartTo, animating: HomeSceneAnimatedTransitions.Modal(.present))
//            nav.push(scene: fullscreenTo, animating: HomeSceneAnimatedTransitions.Modal(.present))

//            nav.push(scene: multipartTo, animating: HomeSceneAnimatedTransitions.Modal(.dismiss))
//            nav.push(scene: fullscreenTo, animating: HomeSceneAnimatedTransitions.Modal(.dismiss))

//            nav.push(scene: multipartTo, animating: HomeSceneAnimatedTransitions.Modal(.swap))
//            nav.push(scene: fullscreenTo, animating: HomeSceneAnimatedTransitions.Modal(.swap))
        }

        return nav
    }

    private func testMap() {
//        map.setCenter(.init(latitude: 60.165791, longitude: 24.941906), zoomLevel: 18, animated: true)
        map.events.subscribe(onNext: { e in print("🗺: \(e)") }).disposed(by: disposeBag)

        let reload = MapReloadSidebarItemView(style: .normal)
        
        let trackUserHighlight: MapSidebarItem.Custom = .init(id: "trackUserHighlighted", content: MapSidebarItem.Content.image(UIImage(named: "map-icon-location-filled")!.withRenderingMode(.alwaysTemplate), tintColor: .red))

        let trackUserNormal: MapSidebarItem.Custom = .init(id: "trackUserNormal", content: MapSidebarItem.Content.image(UIImage(named: "map-icon-location")!.withRenderingMode(.alwaysTemplate), tintColor: .green))

        map.sidebar = [.trackUser(highlightedContent: trackUserHighlight, normalContent: trackUserNormal), .reload(reload)]
        map.events.compactMap(\.map?.didTapSidebarItem?.reload)
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { item in
                item.style = item.style == .normal ? .spinning : .normal
            })
            .disposed(by: disposeBag)

        guard mapLayerManager.requestControlForLayer(with: map.token, transferFromPrevLayer: .init(position: .absolute, options: [])) else {
            print("☠️ couldn't request map layer control")
            return
        }

        // MARK: GeoCache

        let length = 7
        let radius = 2000.0
        let cache = GeoCache<String>(precision: length)
        reload.style = .highlighted

        Observable.combineLatest(
            map.events.compactMap(\.map?.changingPosition).filter(\.status.isEnded),
            map.events.compactMap(\.map?.didTapAnywhere).do(onNext: { [weak self] coord in
                self?.map.overlays.append(.circle(MapCircle(coordinate: coord, radius: radius, lineWidth: 2, fillColor: UIColor.red.withAlphaComponent(0.1))))
                let now = Date()
                cache.insert(items: (1...500).map { _ in .init(value: String.random(length: 3), coordinate: coord) }, aroundCoordinate: coord, inRadius: radius)
                print("📥 \(abs(now.timeIntervalSinceNow))")

//                let ghashes = ProximityHash.geohashes(aroundCoordinate: coord, inRadius: radius, ofLength: length, includingIntersecting: true)
//                let boxes = ghashes.compactMap { ghash, bounds in
//                    GeoHash.Box(geohash: ghash).map { (box: $0, bounds: bounds) }
//                }
//                self?.map.overlays = OrderedSet((self?.map.overlays.contents ?? []) + boxes.map { box, bounds in
//                    MapOverlay.polygon(MapPolygon(coordinates: box.vertices, lineWidth: 2, strokeColor: .blue, fillColor: (bounds == .included ? UIColor.green : UIColor.red).withAlphaComponent(0.1)))
//                })
            })
        )
        .observe(on: MainScheduler.asyncInstance)
        .subscribe(onNext: { args, _ in
            guard reload.style != .spinning else {
                return
            }
            let now = Date()
//            let hasCoverage = args.zoom < 13
//                ? cache.hasCoverage(of: 0.5, inRegion: .circular(.init(center: args.center, radius: radius)))
//                : cache.hasCoverage(of: 0.5, inRegion: .rectangular(.init(region: .init(center: args.center, span: .init(latitudeDelta: args.span.latitudeDelta, longitudeDelta: args.span.longitudeDelta)))))

//            print("📊 \(abs(now.timeIntervalSinceNow)): \(hasCoverage)")
//
//            if !hasCoverage {
//                reload.style = .highlighted
//            } else {
//                reload.style = .normal
//            }

            let result = args.zoom < 13
                ? cache.search(aroundCoordinate: args.center, inRadius: radius)
                : cache.search(inRect: .init(center: args.center, span: .init(latitudeDelta: args.span.latitudeDelta, longitudeDelta: args.span.longitudeDelta)))

            print("📊 \(abs(now.timeIntervalSinceNow)): \(result.coverage)")

            if result.coverage < 0.5 {
                reload.style = .highlighted
            } else {
                reload.style = .normal
            }
        })
        .disposed(by: disposeBag)

        // MARK: Overlays, Routes & Clustering

//        var colors: [UIColor] = [.red, .blue, .magenta, .orange, .purple, .gray]
//        var colorStationMap: [String: UIColor] = [:] {
//            didSet {
//                if colors.isEmpty, oldValue != colorStationMap {
//                    let colorsDescription = colorStationMap.reduce(into: "") { acc, pair in
//                        acc += "\(pair.key): \(pair.value.humanDescription)\n"
//                    }
//                    print("🎨:\n\(colorsDescription)")
//                }
//            }
//        }
//
//        map.events.compactMap(\.map?.didTapOnCluster)
//            .observeOn(MainScheduler.asyncInstance)
//            .subscribe(onNext: { [weak self] clusterMarker in
//                self?.map.setCenter(clusterMarker.cluster.coordinate,
//                    zoomLevel: self?.map.zoomLevel.updatingZoom { $0 + 1 },
//                    animated: true
//                )
//            })
//            .disposed(by: disposeBag)
//
//        map.events.compactMap(\.map?.didSelectMarker)
//            .subscribe(onNext: { marker, isSelected in
//                print("🗺📍: \(marker.clusteringIdentifier), selected: \(isSelected)")
//            })
//            .disposed(by: disposeBag)
//
////        map.clusterMarkerProvider = .init { cluster -> MapClusterMarker in
////            if colorStationMap[cluster.identifier] == nil {
////                colorStationMap[cluster.identifier] = colors.removeFirst()
////            }
////            let color = colorStationMap[cluster.identifier] ?? .black
////            let view = CustomAnotationView(frame: CGRect(x: 0, y: 0, width: 33, height: 33), color: color, text: "\(cluster.items.count)", animated: false)
////            view.layer.cornerRadius = 16.5
////            return MapClusterMarker(
////                cluster: cluster,
////                icon: .image(.init(view.asImage()))
////            )
////        }
//
//        let stationsConfigs = MapClusterConfigs(minimumClusterSize: 10, maximumClusterZoom: 20, animationDuration: 0.5)
//        let eventsConfigs = MapClusterConfigs(minimumClusterSize: 10, maximumClusterZoom: 13, animationDuration: 0.5)
//
//        map.clusterConfigsProvider = .init { clusteringIdentifier in
//            return clusteringIdentifier == "events" ? eventsConfigs : stationsConfigs
//        }
//
//        let markers = testStations.flattened.map { station -> MapMarker in
//            if colorStationMap[station.identifier] == nil {
//                colorStationMap[station.identifier] = colors.removeFirst()
//            }
//            let color = colorStationMap[station.identifier] ?? .black
//            let view = CustomAnotationView(frame: CGRect(x: 0, y: 0, width: 33, height: 33), color: color, text: station.identifier, animated: false)
//            view.layer.cornerRadius = 16.5
//            return MapMarker(
//                coordinate: station.coordinate,
//                icon: .image(CustomAnimatable(view.asImage())),
//                animatesWhenAdded: true,
//                clusteringIdentifier: "stations" // station.identifier
//            )
//        }
//        map.markers = Set(markers)
//
//        let events = testEvents.flattened.map { event -> MapMarker in
//            let view = CustomAnotationView(frame: CGRect(x: 0, y: 0, width: 33, height: 33), color: .black, text: event.identifier, animated: false)
//            view.layer.cornerRadius = 16.5
//            return MapMarker(
//                coordinate: event.coordinate,
//                icon: .image(CustomAnimatable(view.asImage())),
//                animatesWhenAdded: true,
//                clusteringIdentifier: "events"
//            )
//        }
//        map.markers.formUnion(events)
//
//        let quadTree = MapQuadTree(items: Array(markers))
//        map.overlays = OrderedSet(quadTree.allLeaves.map { leaf in
//            .polygon(MapPolygon(
//                coordinates: [
//                    MKMapPoint(x: leaf.rect.maxX, y: leaf.rect.maxY).coordinate,
//                    MKMapPoint(x: leaf.rect.maxX, y: leaf.rect.minY).coordinate,
//                    MKMapPoint(x: leaf.rect.minX, y: leaf.rect.minY).coordinate,
//                    MKMapPoint(x: leaf.rect.minX, y: leaf.rect.maxY).coordinate,
//                ],
//                lineWidth: 2,
//                strokeColor: .blue
//            ))
//        })
//
//        let cs: [UIColor] = [.red, .green, .blue, .yellow, .brown, .magenta, .orange, .purple, .gray, .black, .cyan, .darkGray, .systemTeal, .systemPink, .systemGreen]
//        let pairedRoutes = zip(testEvents.flattened, testEvents.flattened.dropFirst()).enumerated().map { (idx, pair) -> MapRoutePlan in
//            MapRoutePlan(
//                source: pair.0.coordinate,
//                destination: pair.1.coordinate,
//                transportType: [.walking],
//                renderWhen: .zoomGreaterThan(13),
//                polylinesProvider: .init { response -> OrderedSet<MapPolyline> in
//                    [MapPolyline(coordinates: response.coordinates, lineWidth: 2, strokeColor: cs[idx])]
//                }
//            )
//        }
//        map.plannedRoutes = OrderedSet(pairedRoutes)
    }
}

private final class CustomAnotationView: UIView {
    private let shouldAnimate: Bool

    init(frame: CGRect, color: UIColor, text: String? = nil, animated: Bool) {
        shouldAnimate = animated
        super.init(frame: frame)
        backgroundColor = color

        if let text = text {
            let label = UILabel(frame: .init(x: 3, y: 0, width: 27, height: 33))
            label.textColor = .white
            label.text = text
            label.font.withSize(20)
            label.minimumScaleFactor = 0.3
            label.adjustsFontSizeToFitWidth = true
            label.textAlignment = .center
            addSubview(label)

        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        guard shouldAnimate, superview != nil else { return }

        layer.removeAllAnimations()
        transform = CGAffineTransform(scaleX: 0, y: 0)

        UIView.animate(withDuration: 3, delay: 0, options: .curveEaseOut, animations: {
            self.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        }, completion: { _ in
            UIView.animate(withDuration: 2, delay: 0, options: .curveEaseInOut, animations: {
                self.transform = .identity
            })
        })
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()

        guard shouldAnimate else { return }

        layer.removeAllAnimations()
        transform = .identity

        UIView.animate(withDuration: 3, delay: 0, options: .curveEaseIn, animations: {
            self.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
        }, completion: { _ in
            self.transform = .identity
        })
    }
}

private extension UIView {
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}

class NextTopBar: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .blue
    }
}

class NextSceneBottomSheet: UIViewController, BottomPanel {
    private(set) lazy var bottomPanelHandler = BottomPanelHandler(bottomPanel: self)

    var bottomPanelInitialStickyPoint: BottomPanelStickyPoint { .fromBottom(.points(400)) }
    var bottomPanelStickyPoints: Set<BottomPanelStickyPoint> { [.fromTop(.points(100))] }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .blue
    }
}

let testBuses: [(coordinate: CLLocationCoordinate2D, identifier: String)] = [
    (CLLocationCoordinate2D(latitude: 60.16892, longitude: 24.93137), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.1611, longitude: 24.92455), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.165495, longitude: 24.9269), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17119, longitude: 24.925518), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17076, longitude: 24.94268), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.15591, longitude: 24.94897), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.169066, longitude: 24.931895), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.169711, longitude: 24.933736), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.178258, longitude: 24.953103), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.162596, longitude: 24.915995), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16542, longitude: 24.95278), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.1689, longitude: 24.93128), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.15559, longitude: 24.94633), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.161408, longitude: 24.938831), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.15939, longitude: 24.954144), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.15823, longitude: 24.94513), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17113, longitude: 24.9448), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17072, longitude: 24.94324), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.160917, longitude: 24.93791), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.169432, longitude: 24.930045), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16075, longitude: 24.94636), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.160642, longitude: 24.955804), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16818, longitude: 24.923302), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16887, longitude: 24.93119), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.171681, longitude: 24.939739), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.169092, longitude: 24.931967), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17932, longitude: 24.95073), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.171801, longitude: 24.939727), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17033, longitude: 24.93807), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.157425, longitude: 24.945507), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.168, longitude: 24.95403), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.159124, longitude: 24.946388), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.1628, longitude: 24.94603), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.167459, longitude: 24.942515), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.171203, longitude: 24.93958), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16885, longitude: 24.93109), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17428, longitude: 24.96071), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17886, longitude: 24.95075), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.1688, longitude: 24.93093), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16622, longitude: 24.92673), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.172041, longitude: 24.939704), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17913, longitude: 24.952221), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17164, longitude: 24.94299), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.15788, longitude: 24.94127), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16522, longitude: 24.94405), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.159542, longitude: 24.95471), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16875, longitude: 24.9353), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.165618, longitude: 24.931375), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.15686, longitude: 24.94528), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17098, longitude: 24.9427), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17502, longitude: 24.95049), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.170863, longitude: 24.938568), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.169022, longitude: 24.931713), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17034, longitude: 24.94382), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16714, longitude: 24.94234), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.178205, longitude: 24.951532), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.169, longitude: 24.93164), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17331, longitude: 24.94921), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.171981, longitude: 24.93971), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.1688, longitude: 24.93012), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17714, longitude: 24.92988), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16936, longitude: 24.95698), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17085, longitude: 24.94333), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17258, longitude: 24.956554), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.169119, longitude: 24.932058), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.169588, longitude: 24.933372), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.170862, longitude: 24.930898), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16477, longitude: 24.94331), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17016, longitude: 24.92995), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17027, longitude: 24.937555), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.168381, longitude: 24.93238), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16946, longitude: 24.95667), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.15751, longitude: 24.94903), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.1625, longitude: 24.93574), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16494, longitude: 24.93622), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17209, longitude: 24.92367), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.168775, longitude: 24.92859), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.158483, longitude: 24.949833), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16121, longitude: 24.94652), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.1736, longitude: 24.94958), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.1788, longitude: 24.94977), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.164261, longitude: 24.936553), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17192, longitude: 24.94376), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17083, longitude: 24.92517), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.163645, longitude: 24.934098), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.173291, longitude: 24.943217), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17022, longitude: 24.93943), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16898, longitude: 24.93155), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.173957, longitude: 24.956414), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.178438, longitude: 24.95265), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17433, longitude: 24.96023), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.171229, longitude: 24.95655), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.171921, longitude: 24.939716), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17419, longitude: 24.93349), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.158277, longitude: 24.94121), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.160941, longitude: 24.95634), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.178907, longitude: 24.952209), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17004, longitude: 24.91991), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17132, longitude: 24.94302), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.168809, longitude: 24.935728), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.171741, longitude: 24.939733), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.168485, longitude: 24.923568), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.1684, longitude: 24.93178), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.172101, longitude: 24.939698), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17108, longitude: 24.94283), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17141, longitude: 24.94266), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.170187, longitude: 24.939029), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17112, longitude: 24.93338), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17856, longitude: 24.94992), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.171861, longitude: 24.939722), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17884, longitude: 24.92917), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17133, longitude: 24.94277), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.174161, longitude: 24.95678), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17139, longitude: 24.92368), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17095, longitude: 24.94308), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17164, longitude: 24.94276), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16061, longitude: 24.94144), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16196, longitude: 24.92906), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.178682, longitude: 24.952168), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17134, longitude: 24.94329), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.165501, longitude: 24.951317), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17165, longitude: 24.94327), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16431, longitude: 24.91405), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16895, longitude: 24.93146), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16192, longitude: 24.92366), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.167258, longitude: 24.932995), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.1554, longitude: 24.94244), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.169156, longitude: 24.930101), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.17299, longitude: 24.95638), "BUS"),
    (CLLocationCoordinate2D(latitude: 60.16904, longitude: 24.931804), "BUS")
]

let testTrams: [(coordinate: CLLocationCoordinate2D, identifier: String)] = [
    (CLLocationCoordinate2D(latitude: 60.17842, longitude: 24.92938), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16618, longitude: 24.96881), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.163603, longitude: 24.935071), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.157988, longitude: 24.940139), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17341, longitude: 24.92265), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.1627, longitude: 24.92315), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.171298, longitude: 24.925017), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16211, longitude: 24.94831), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16776, longitude: 24.9313), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.1748, longitude: 24.93261), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.161274, longitude: 24.941349), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16563, longitude: 24.96831), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16465, longitude: 24.93775), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16469, longitude: 24.938115), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.1673, longitude: 24.9212), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.15783, longitude: 24.93573), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17805, longitude: 24.92931), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.15956, longitude: 24.95505), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.169031, longitude: 24.949924), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17511, longitude: 24.93235), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.162562, longitude: 24.931858), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16761, longitude: 24.9522), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16886, longitude: 24.94206), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16676, longitude: 24.96486), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.163552, longitude: 24.919945), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.179068, longitude: 24.950066), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.171727, longitude: 24.920245), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.160225, longitude: 24.920807), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.163533, longitude: 24.920651), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.171155, longitude: 24.931459), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17216, longitude: 24.95335), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.1674, longitude: 24.96286), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16621, longitude: 24.94236), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.158449, longitude: 24.934163), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.1617, longitude: 24.928), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.15825, longitude: 24.94543), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17183, longitude: 24.95326), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16893, longitude: 24.94613), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16823, longitude: 24.9411), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16332, longitude: 24.94539), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.1585, longitude: 24.94946), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16156, longitude: 24.95638), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.1651, longitude: 24.95253), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.171783, longitude: 24.947617), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16146, longitude: 24.92483), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16089, longitude: 24.94178), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.162237, longitude: 24.931177), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17285, longitude: 24.92295), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16611, longitude: 24.96915), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16545, longitude: 24.92693), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.1704, longitude: 24.94061), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16915, longitude: 24.95611), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17407, longitude: 24.95208), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16843, longitude: 24.92115), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16743, longitude: 24.96186), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16288, longitude: 24.93909), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.171232, longitude: 24.920375), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16795, longitude: 24.93143), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17045, longitude: 24.9377), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17036, longitude: 24.95353), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17036, longitude: 24.9413), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.158017, longitude: 24.9419), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16901, longitude: 24.95046), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.171159, longitude: 24.930751), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.161023, longitude: 24.947501), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16428, longitude: 24.9697), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16912, longitude: 24.95556), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.179221, longitude: 24.950207), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16281, longitude: 24.92489), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17165, longitude: 24.94751), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16736, longitude: 24.95171), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.1599, longitude: 24.92135), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16776, longitude: 24.94159), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17021, longitude: 24.94523), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16346, longitude: 24.92768), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.1689, longitude: 24.94686), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.17023, longitude: 24.93798), "TRAM"),
    (CLLocationCoordinate2D(latitude: 60.16874, longitude: 24.94248), "TRAM"),
]

let testTrains: [(coordinate: CLLocationCoordinate2D, identifier: String)] = [
    (CLLocationCoordinate2D(latitude: 60.171298, longitude: 24.941671), "TRAIN"),
    (CLLocationCoordinate2D(latitude: 60.172987, longitude: 24.941576), "TRAIN"),
    (CLLocationCoordinate2D(latitude: 60.172732, longitude: 24.939551), "TRAIN"),
    (CLLocationCoordinate2D(latitude: 60.172992, longitude: 24.942044), "TRAIN"),
    (CLLocationCoordinate2D(latitude: 60.17272, longitude: 24.939911), "TRAIN"),
]

let testSubways: [(coordinate: CLLocationCoordinate2D, identifier: String)] = [
    (CLLocationCoordinate2D(latitude: 60.16883, longitude: 24.931215), "SUBWAY"),
    (CLLocationCoordinate2D(latitude: 60.170388, longitude: 24.939845), "SUBWAY"),
    (CLLocationCoordinate2D(latitude: 60.172026, longitude: 24.94785), "SUBWAY"),
]

let testFerries: [(coordinate: CLLocationCoordinate2D, identifier: String)] = [
    (CLLocationCoordinate2D(latitude: 60.167248, longitude: 24.955786), "FERRY"),
]

let luxInstallations: [(coordinate: CLLocationCoordinate2D, identifier: String)] = [
    (CLLocationCoordinate2D(latitude: 60.176347336123492, longitude: 24.924183408788689), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.174853279523944, longitude: 24.911823789648064), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.176347336123492, longitude: 24.908648054174432), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.17515209628062, longitude: 24.912081281713494), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.173871433897567, longitude: 24.958172361425408), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.166656102856933, longitude: 24.959202329687127), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.169257967404349, longitude: 24.922929476074227), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.163538931294575, longitude: 24.951563398412713), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.17301763123595, longitude: 24.934139768651971), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.162054899145204, longitude: 24.911036342382431), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.160175828326594, longitude: 24.935068935155869), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.161489123095258, longitude: 24.926500837377557), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.162471338811436, longitude: 24.884014646581658), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.16789434921882, longitude: 24.941950361303338), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.173444535340742, longitude: 24.944782774023064), "LUX"),
    (CLLocationCoordinate2D(latitude: 60.175835095802341, longitude: 24.937487165502557), "LUX")

]

let testStations = [testBuses, testTrams, testTrains, testSubways, testFerries]
let testEvents = [luxInstallations]

private extension UIColor {
    var humanDescription: String {
        switch self {
        case .red: return "red"
        case .green: return "green"
        case .yellow: return "yellow"
        case .blue: return "blue"
        case .orange: return "orange"
        case .purple: return "purple"
        case .magenta: return "magenta"
        case .gray: return "gray"
        default: return "other \(self)"
        }
    }
}
