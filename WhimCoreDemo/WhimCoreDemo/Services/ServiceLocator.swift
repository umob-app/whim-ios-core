/// How To Control The World
///   * [Service Locator](https://gameprogrammingpatterns.com/service-locator.html)
///   * [NSSPain Talk](https://vimeo.com/291588126)
///   * Pointfree episodes [16](https://www.pointfree.co/episodes/ep16-dependency-injection-made-easy) and [18](https://www.pointfree.co/episodes/ep18-dependency-injection-made-comfortable)
///   * [BabylonHealth Example](https://github.com/babylonhealth/ios-playbook/blob/master/Cookbook/Proposals/ControlTheWorld.md)
///
struct ServiceLocator {
    let mapLayerManager: DemoMapLayerManager
    let userLocationService: UserLocationServing
    let worldGeometryService: WorldGeometryServing
    // etc...
}

extension ServiceLocator {
    private static var serviceLocator: ServiceLocator!

    static var current: ServiceLocator { serviceLocator }

    static func setAsCurrent(serviceLocator: ServiceLocator) {
        Self.serviceLocator = serviceLocator
    }
}

extension ServiceLocator {
    static func reset() {
        ServiceLocator.setAsCurrent(serviceLocator: ServiceLocator.create())
    }
}

// MARK: - Dependencies

extension ServiceLocator {
    static func create() -> ServiceLocator {
        ServiceLocator(
            mapLayerManager: DemoMapLayerManager(),
            userLocationService: UserLocationService(),
            worldGeometryService: WorldGeometryService()
        )
    }
}
