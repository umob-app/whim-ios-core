import WhimRandom
import WhimCore

extension MapSidebarItem: RandomAll {
    public static func allRandom<G: RandomNumberGenerator>(using generator: inout G) -> [MapSidebarItem] {
        return [
            .trackUser(highlightedContent: nil, normalContent: nil),
            .reload(MapReloadSidebarItemView(style: .random(using: &generator), highlightColor: .blue, normalTintColor: .red)),
            .custom(.random(using: &generator))
        ]
    }

    public static func random(
        reload: MapSidebarItem = .reload(MapReloadSidebarItemView(style: .random(using: &R), highlightColor: .blue, normalTintColor: .red)),
        custom: MapSidebarItem = .custom(.random(using: &R))
    ) -> MapSidebarItem {
        return [
            .trackUser(highlightedContent: nil, normalContent: nil),
            reload,
            custom
        ].randomElement(using: &R)!
    }
}
