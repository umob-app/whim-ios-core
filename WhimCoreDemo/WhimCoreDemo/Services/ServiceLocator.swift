struct ServiceLocator {
    let mapLayerManager: DemoMapLayerManager
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
            worldGeometryService: WorldGeometryService()
        )
    }
}
