import MapKit

// MARK: - Item

public protocol QuadTreeItem {
    var position: CLLocationCoordinate2D { get }
}

// MARK: - Tree

public typealias MapQuadTree = QuadTree<MapMarker>

/// QuadTree data structure.
///
/// Implementation examples:
/// - [google-maps-ios-utils/GQTPointQuadTree](https://github.com/googlemaps/google-maps-ios-utils/blob/master/src/QuadTree/GQTPointQuadTree.h)
/// - [Cluster/QuadTree](https://github.com/efremidze/Cluster/blob/master/Sources/QuadTree.swift)
///
/// Data structure description:
///  - [Wikipedia - Quadtree](https://en.wikipedia.org/wiki/Quadtree)
///
/// ---
/// - Note: This class is not thread safe.
public final class QuadTree<Item: QuadTreeItem> {
    public enum Node {
        case leaf(Leaf)
        indirect case children(Children)

        static var maxCapacity: Int { 64 }
        static var maxDepth: Int { 30 }

        public final class Leaf {
            public let rect: MKMapRect
            public fileprivate(set) var items: [Item]
            public let depth: Int

            public init(rect: MKMapRect, depth: Int) {
                self.rect = rect
                self.items = []
                self.depth = depth
            }
        }

        public final class Children {
            public fileprivate(set) var northWest, northEast, southWest, southEast: Node

            public init(rect: MKMapRect, depth: Int) {
                let deeper = depth + 1

                self.northWest = .leaf(Leaf(rect: .init(minX: rect.minX, minY: rect.minY, maxX: rect.midX, maxY: rect.midY), depth: deeper))
                self.northEast = .leaf(Leaf(rect: .init(minX: rect.midX, minY: rect.minY, maxX: rect.maxX, maxY: rect.midY), depth: deeper))
                self.southWest = .leaf(Leaf(rect: .init(minX: rect.minX, minY: rect.midY, maxX: rect.midX, maxY: rect.maxY), depth: deeper))
                self.southEast = .leaf(Leaf(rect: .init(minX: rect.midX, minY: rect.midY, maxX: rect.maxX, maxY: rect.maxY), depth: deeper))
            }
        }
    }

    public private(set) var root: Node
    let rect: MKMapRect

    /// Create a QuadTree with map rect.
    ///
    /// - Parameters:
    ///   - rect: The map rect of this QuadTree. The tree will only accept items that fall within the rect. The rect is inclusive.
    ///     Defaults to the `world` map rect.
    ///   - items: Items that should be immediately added to this QuadTree up construction. Defaults to `[]`.
    public init(rect: MKMapRect = .world, items: [Item] = []) {
        self.rect = rect
        self.root = .leaf(.init(rect: rect, depth: 0))

        for item in items { 
            root.add(item)
        }
    }
}

public extension QuadTree {
    /// Insert an item into this QuadTree.
    ///
    /// - Returns: `false` if the item is not contained within the rect of this tree. Otherwise adds the item and returns `true`.
    @discardableResult
    func add(_ item: Item) -> Bool {
        root.add(item)
    }

    /// Delete an item from this QuadTree.
    ///
    /// - Returns: `false` if the items was not found in the tree, `true` otherwise.
    @discardableResult
    func remove(_ item: Item) -> Bool {
        root.remove(item)
    }

    /// Delete all items from this QuadTree.
    func clear() {
        root = .leaf(.init(rect: rect, depth: 0))
    }

    /// Retreive all items in this QuadTree within a map rect.
    ///
    /// - Returns: The collection of items within `rect`.
    func items(in rect: MKMapRect) -> [Item] {
        root.items(in: rect)
    }
}

// MARK: Node

public extension QuadTree.Node {
    var leaf: Leaf? {
        guard case let .leaf(value) = self else { return nil }
        return value
    }

    var children: Children? {
        guard case let .children(value) = self else { return nil }
        return value
    }

    @discardableResult
    mutating func add(_ item: Item) -> Bool {
        switch self {
        case let .leaf(leaf):
            guard leaf.rect.contains(item.position) else {
                return false
            }
            leaf.items.append(item)
            if leaf.items.count > Self.maxCapacity && leaf.depth < Self.maxDepth {
                self = leaf.subdivided()
            }
            return true
        case let .children(children):
            return children.updateFirstMatchingNode { node in
                node.add(item)
            }
        }
    }

    @discardableResult
    func remove(_ item: Item) -> Bool {
        switch self {
        case let .leaf(leaf):
            guard leaf.rect.contains(item.position) else {
                return false
            }
            if let index = leaf.items.map(\.position).firstIndex(of: item.position) {
                leaf.items.remove(at: index)
                return true
            }
            return false
        case let .children(children):
            return children.updateFirstMatchingNode { node in
                node.remove(item)
            }
        }
    }

    func items(in rect: MKMapRect) -> [Item] {
        switch self {
        case let .leaf(leaf):
            guard leaf.rect.intersects(rect) else {
                return []
            }
            return leaf.items.filter { item in
                rect.contains(item.position)
            }
        case let .children(children):
            return children.nodes.flatMap { node in
                node.items(in: rect)
            }
        }
    }
}

// MARK: Leaf

extension QuadTree.Node.Leaf {
    func subdivided() -> QuadTree.Node {
        let children = QuadTree.Node.Children(rect: rect, depth: depth)
        for item in items {
            children.updateFirstMatchingNode { node in
                node.add(item)
            }
        }
        return .children(children)
    }
}

// MARK: Children

extension QuadTree.Node.Children {
    var nodes: [QuadTree.Node] {
        [northWest, northEast, southWest, southEast]
    }

    @discardableResult
    func updateFirstMatchingNode(_ transform: (inout QuadTree.Node) -> Bool) -> Bool {
        return transform(&northWest) || transform(&northEast) || transform(&southWest) || transform(&southEast)
    }
}

// MARK: - Helpers

public extension MKMapRect {
    init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.init(x: minX, y: minY, width: abs(maxX - minX), height: abs(maxY - minY))
    }

    init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: MKMapPoint(x: x, y: y), size: MKMapSize(width: width, height: height))
    }

    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        contains(MKMapPoint(coordinate))
    }
}

extension MapMarker: QuadTreeItem {
    public var position: CLLocationCoordinate2D {
        return coordinate.value.value
    }
}

public extension QuadTree {
    var allItems: [Item] {
        allLeaves.flatMap(\.items)
    }

    var allLeaves: [Node.Leaf] {
        root.allLeaves
    }
}

public extension QuadTree.Node {
    var allLeaves: [Leaf] {
        switch self {
        case let .leaf(leaf):
            return [leaf]
        case let .children(children):
            return children.nodes.reduce(into: []) { (acc, node) in
                acc.append(contentsOf: node.allLeaves)
            }
        }
    }
}


// MARK: - Debugging

extension QuadTree: CustomDebugStringConvertible {
    public var debugDescription: String {
        "🌳 Tree: \n" + root.debugDescription
    }
}

extension QuadTree.Node: CustomDebugStringConvertible {
    public var debugDescription: String {
         switch self {
         case let .leaf(leaf):
             return repeatElement("\t", count: leaf.depth) + "- \(leaf.depth): leaf \(leaf.items.count)"
         case let .children(children):
             return children.nodes.map { node in
                 node.debugDescription
             }
             .joined(separator: "\n")
         }
    }
}
