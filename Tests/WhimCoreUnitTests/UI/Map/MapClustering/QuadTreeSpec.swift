import Foundation
import Quick
import Nimble
import MapKit

@testable import WhimCore

class QuadTreeSpec: QuickSpec {
    override func spec() {
        describe("QuadTree") {
            typealias SUT = QuadTree<TestItem>

            var sut: SUT!

            describe("when initialized") {
                context("without items") {
                    it("should contain empty leaf root node with zero depth and full given rect") {
                        let rect = MKMapRect.sample
                        sut = SUT(rect: rect)

                        expect(sut.root.leaf?.items).to(beEmpty())
                        expect(sut.root.leaf?.depth).to(equal(0))
                        expect(sut.root.leaf?.rect).to(equal(rect))
                    }
                }

                context("with items") {
                    it("should include items that are inside given rect bounds and ignore the rest") {
                        let rect = MKMapRect.sample
                        let range = rect.range
                        sut = SUT(rect: rect, items: [
                            .init(point: .random(x: range.x, y: range.y, using: &R)),
                            .init(point: .random(x: range.x, y: range.y, using: &R)),
                            .init(point: .random(x: range.x.offset(by: 1), y: range.y.offset(by: 1), using: &R))
                        ])

                        expect(sut.root.leaf?.items).to(haveCount(2))
                        expect(sut.root.leaf?.depth).to(equal(0))
                        expect(sut.root.leaf?.rect).to(equal(rect))
                    }
                }
            }

            describe("when adding item") {
                beforeEach {
                    sut = SUT(rect: MKMapRect.sample)
                }

                context("which is inside rect bounds") {
                    it("should add it and return true") {
                        let range = sut.rect.range
                        let result = sut.add(.init(point: .random(x: range.x, y: range.y, using: &R)))

                        expect(sut.root.leaf?.items).to(haveCount(1))
                        expect(result).to(beTrue())
                    }

                    context("and max leaf capacity is exceeded") {
                        beforeEach {
                            let range = sut.rect.range

                            for _ in 0 ..< SUT.Node.maxCapacity {
                                sut.add(.init(point: .random(x: range.x, y: range.y, using: &R)))
                            }
                        }

                        it("should keep original rect intact") {
                            let origSutRect = sut.rect

                            sut.add(.init(point: .random(x: sut.rect.range.x, y: sut.rect.range.y, using: &R)))

                            expect(sut.rect).to(equal(origSutRect))
                        }

                        it("should distribute items among children correctly") {
                            sut.add(.init(point: .random(x: sut.rect.range.x, y: sut.rect.range.y, using: &R)))

                            let nodeItemsDistributedCorrectly = sut.root.children?.nodes.map { node in
                                node.leaf!.items.allSatisfy { node.leaf!.rect.contains($0.position) }
                            }
                            expect(nodeItemsDistributedCorrectly).to(allPass(beTrue()))
                            expect(sut.root.children?.nodes.map(\.leaf!.items.count).reduce(0, +)).to(equal(SUT.Node.maxCapacity + 1))
                        }

                        it("should be divided into four equal children") {
                            let origRect = sut.root.leaf?.rect

                            sut.add(.init(point: .random(x: sut.rect.range.x, y: sut.rect.range.y, using: &R)))

                            let sizes = sut.root.children?.nodes.map(\.leaf!.rect.size)
                            expect(sizes).to(allPass(equal(sizes?.first)))
                            expect(origRect!.width / 2).to(equal(sizes?.first?.width))
                            expect(origRect!.height / 2).to(equal(sizes?.first?.height))

                            let nodes = sut.root.children
                            expect([nodes!.northWest, nodes!.southWest].map { $0.leaf!.rect.minX }).to(allPass(equal(origRect!.minX)))
                            expect([nodes!.northWest, nodes!.northEast].map { $0.leaf!.rect.minY }).to(allPass(equal(origRect!.minY)))
                            expect([nodes!.southEast, nodes!.northEast].map { $0.leaf!.rect.maxX }).to(allPass(equal(origRect!.maxX)))
                            expect([nodes!.southEast, nodes!.southWest].map { $0.leaf!.rect.maxY }).to(allPass(equal(origRect!.maxY)))
                        }

                        it("should move one level deeper") {
                            sut.add(.init(point: .random(x: sut.rect.range.x, y: sut.rect.range.y, using: &R)))

                            expect(sut.root.children?.nodes.map(\.leaf!.depth)).to(allPass(equal(1)))
                        }
                    }

                    context("and max node depth is exceeded") {
                        beforeEach {
                            sut = SUT(rect: MKMapRect.world)

                            for _ in 0 ... SUT.Node.maxDepth + 1 {
                                let range = sut.root.deepestLeaf.rect.range

                                for _ in 0 ... SUT.Node.maxCapacity {
                                    sut.add(.init(point: .random(x: range.x, y: range.y, using: &R)))
                                }
                            }
                        }

                        it("should stop dividing deepest rects and should keep adding items into them") {
                            let deepestLeaf = sut.root.deepestLeaf

                            expect(deepestLeaf.depth).to(equal(SUT.Node.maxDepth))
                            expect(deepestLeaf.items.count).to(beGreaterThan(SUT.Node.maxCapacity))
                        }
                    }
                }

                context("which is on the edge of rect bounds") {
                    it("should add it and return true") {
                        let range = sut.rect.range
                        let result = sut.add(.init(point: MKMapPoint(x: range.x.upperBound, y: range.y.upperBound)))

                        expect(sut.root.leaf?.items).to(haveCount(1))
                        expect(result).to(beTrue())
                    }
                }

                context("which is outside of rect bounds") {
                    it("should ignore it and return false") {
                        let range = sut.rect.range
                        let result = sut.add(.init(point: .random(x: range.x.offset(by: 1), y: range.y.offset(by: 1), using: &R)))

                        expect(sut.root.leaf?.items).to(beEmpty())
                        expect(result).to(beFalse())
                    }
                }
            }

            describe("when removing item") {
                beforeEach {
                    let rect = MKMapRect.sample
                    let range = rect.range
                    sut = SUT(rect: rect)

                    for _ in 0 ... SUT.Node.maxCapacity {
                        sut.add(.init(point: .random(x: range.x, y: range.y, using: &R)))
                    }
                }

                context("which is inside rect bounds") {
                    context("and it contains such item") {
                        it("should remove it and return true") {
                            let remove = sut.allItems.first!
                            let count = sut.allItems.count
                            let result = sut.remove(remove)

                            expect(sut.allItems.contains(where: { $0.position == remove.position })).to(beFalse())
                            expect(sut.allItems.count).to(equal(count - 1))
                            expect(result).to(beTrue())
                        }

                        it("should keep existing structure even if there are no items in the node") {
                            for item in sut.allItems {
                                sut.remove(item)
                            }

                            expect(sut.allItems).to(beEmpty())
                            expect(sut.root.children).toNot(beNil())
                        }
                    }

                    context("and it doesn't contain such item") {
                        it("return false") {
                            let count = sut.allItems.count
                            let result = sut.remove(.init(point: MKMapPoint.random(x: sut.rect.range.x, y: sut.rect.range.y, using: &R)))

                            expect(result).to(beFalse())
                            expect(sut.allItems.count).to(equal(count))
                        }
                    }
                }

                context("which is outside of rect bounds") {
                    it("should do nothing return false") {
                        let count = sut.allItems.count
                        let remove = TestItem(point: MKMapPoint.random(
                            x: sut.rect.range.x.offset(by: sut.rect.width),
                            y: sut.rect.range.y.offset(by: sut.rect.height),
                            using: &R
                        ))
                        let result = sut.remove(remove)

                        expect(result).to(beFalse())
                        expect(sut.allItems.count).to(equal(count))
                    }
                }
            }

            describe("when clearing") {
                beforeEach {
                    let rect = MKMapRect.sample
                    let range = rect.range
                    sut = SUT(rect: rect)

                    for _ in 0 ... 100 {
                        sut.add(.init(point: .random(x: range.x, y: range.y, using: &R)))
                    }
                }

                it("should drop everything to root leaf with original rect and no items") {
                    sut.clear()

                    expect(sut.root.leaf?.rect).to(equal(sut.rect))
                    expect(sut.root.leaf?.items).to(beEmpty())
                    expect(sut.root.leaf?.depth).to(equal(0))
                }
            }

            describe("when searching items in rect") {
                beforeEach {
                    let rect = MKMapRect.sample
                    let range = rect.range
                    sut = SUT(rect: rect)

                    for _ in 0 ... 1000 {
                        sut.add(.init(point: .random(x: range.x, y: range.y, using: &R)))
                    }
                }

                it("should return all items that belong to that rect no matter in what node and how deep they are") {
                    let rect = MKMapRect(
                        x: sut.rect.origin.x + sut.rect.width / 2,
                        y: sut.rect.origin.y + sut.rect.height / 2,
                        width: sut.rect.width / 2,
                        height: sut.rect.height / 2
                    )
                    let result = sut.items(in: rect)

                    expect(result.map { rect.contains($0.position) }).to(allPass(beTrue()))

                    let rest = Set(sut.allItems.map(\.position)).subtracting(result.map(\.position))
                    expect(rest.map(rect.contains)).to(allPass(beFalse()))
                }
            }
        }
    }
}

// MARK: - Helpers

private struct TestItem: QuadTreeItem {
    let point: MKMapPoint

    var position: CLLocationCoordinate2D { point.coordinate }

    init(coord: CLLocationCoordinate2D) { self.point = MKMapPoint(coord) }
    init(point: MKMapPoint) { self.point = point }
}

private extension QuadTree.Node {
    var deepestLeaf: QuadTree.Node.Leaf {
        switch self {
        case let .leaf(leaf):
            return leaf
        case let .children(children):
            // will choose first sub-rect as north-west and then will keep choosing south-east to be closer to the center of the rect,
            // as going always north-west might end up with lots of invalid coordinates because of the -180 lon and ~85.05 lat,
            // which are closer to the north pole and edge of the 180th span and are harder to calculate for the MapKit ¯\_(ツ)_/¯
            if let leaf = children.nodes.compactMap(\.leaf).first, leaf.depth == 1 {
                return children.northWest.deepestLeaf
            }
            return children.southEast.deepestLeaf
        }
    }
}

private extension ClosedRange where Bound: FloatingPoint {
    func offset(by delta: Bound) -> ClosedRange {
        return (lowerBound + delta) ... (upperBound + delta)
    }
}

private extension MKMapRect {
    static var sample: MKMapRect {
        return MKMapRect(x: world.midX, y: world.midY, width: 1, height: 1)
    }

    var range: (x: ClosedRange<Double>, y: ClosedRange<Double>) {
        return (x: minX ... maxX, y: minY ... maxY)
    }
}
