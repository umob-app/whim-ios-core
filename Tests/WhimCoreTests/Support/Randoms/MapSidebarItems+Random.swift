import WhimRandom
import WhimCore

extension MapSidebarItem: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [MapSidebarItem] {
        return [
            .trackUser,
            .reload(MapReloadSidebarItemView(style: .random(using: &generator))),
            .custom(.random(using: &generator))
        ]
    }

    public static func random(
        reload: MapSidebarItem = .reload(MapReloadSidebarItemView(style: .random(using: &R))),
        custom: MapSidebarItem = .custom(.random(using: &R))
    ) -> MapSidebarItem {
        return [
            .trackUser,
            reload,
            custom
        ].randomElement(using: &R)!
    }
}
