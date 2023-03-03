import Foundation
import Quick
import Nimble
import CoreLocation
import RxSwift
import RxRelay
import SwiftyMock
import WhimRandom

@testable import WhimCore

final class MapLayerSettingSpec: QuickSpec {
    override func spec() {
        describe("MapLayerSetting") {
            var sut: MapLayer<MapContext>!
            var observer: FunctionCall<MapLayerState, Void>!

            beforeEach {
                observer = FunctionCall()
                sut = MapLayerManager.testLayer { [weak observer] state in
                    observer.map { stubCall($0, argument: state, defaultValue: ()) }
                }
            }

            describe("when setting") {
                context("configs") {
                    it("should notify observer about new state") {
                        sut.configs.subtract([.isZoomEnabled])

                        expect(observer.capturedArgument?.configs.contains(.isZoomEnabled)).to(beFalse())
                    }
                }

                context("visible rect inset") {
                    it("should notify observer about new state") {
                        sut.visibleRectInset = .custom(bottom: 42)

                        expect(observer.capturedArgument?.visibleRectInset.bottom.value).to(equal(42))
                    }
                }

                context("sidebar") {
                    it("should notify observer about new state") {
                        let image = UIImage()
                        sut.sidebar.append(.custom(id: "abc", image: image))

                        expect(observer.capturedArgument?.sidebar).to(haveCount(2))
                        expect(observer.capturedArgument?.sidebar.last?.content().image).to(beIdenticalTo(image))
                    }
                }

                context("markers") {
                    var markers: Set<MapMarker>!

                    beforeEach {
                        markers = Set<MapMarker>.random(ofLength: 3, using: &R)
                        sut.markers = markers
                    }

                    it("should notify observer about new state") {
                        expect(observer.capturedArgument?.markers).to(equal(markers))
                    }

                    context("while having selected marker") {
                        var newMarkers: Set<MapMarker>!
                        var selected: MapMarker!

                        beforeEach {
                            selected = markers.first!
                            random([
                                { sut.selectMarker(selected) },
                                { sut.handle(event: .didSelectMarker(selected, true)) }
                            ], using: &R)
                        }

                        context("and new markers contain it") {
                            beforeEach {
                                newMarkers = markers
                                sut.markers = newMarkers
                            }

                            it("should stay selected") {
                                expect(sut.selectedMarker?.value).to(equal(selected))
                            }
                        }

                        context("and new markers don't contain it") {
                            beforeEach {
                                newMarkers = Set<MapMarker>.random(ofLength: 3, using: &R)
                                sut.markers = newMarkers
                            }

                            it("should become nil") {
                                expect(sut.selectedMarker).to(beNil())
                            }
                        }
                    }
                }

                context("selected marker") {
                    var marker: MapMarker!

                    beforeEach {
                        marker = MapMarker.random(using: &R)
                    }

                    context("belonging to this layer") {
                        beforeEach {
                            sut.markers = [marker]
                        }

                        it("should mark it as selecting first") {
                            sut.selectMarker(marker)

                            expect(sut.selectedMarker?.isSelecting).to(beTrue())
                        }

                        it("should notify observer") {
                            sut.selectMarker(marker)

                            expect(observer.capturedArgument?.markerSelection).to(equal(.selecting(marker)))
                        }
                    }

                    context("not belonging to this layer") {
                        it("should ignore it") {
                            sut.selectMarker(marker)

                            expect(sut.selectedMarker).to(beNil())
                        }

                        it("should not notify observer") {
                            sut.selectMarker(marker)

                            expect(observer.capturedArguments).to(beEmpty())
                        }
                    }

                    context("being already selected") {
                        beforeEach {
                            sut.markers = [marker]
                            sut.handle(event: .didSelectMarker(marker, true))
                        }

                        it("should keep it selected") {
                            sut.selectMarker(marker)

                            expect(sut.selectedMarker?.isSelected).to(beTrue())
                        }

                        it("should not notify observer") {
                            sut.selectMarker(marker)

                            // only one observer event for setting markers, and none for selecting already selected marker
                            expect(observer.capturedArguments).to(haveCount(1))
                        }
                    }
                }

                context("any marker deselected") {
                    var marker: MapMarker!

                    beforeEach {
                        marker = MapMarker.random(using: &R)
                        sut.markers = [marker]
                    }

                    context("and there is no selected marker") {
                        it("should keep it empty") {
                            sut.deselectAnyMarker()

                            expect(sut.selectedMarker).to(beNil())
                        }

                        it("should not notify observer") {
                            sut.deselectAnyMarker()

                            // only one observer event for setting markers, and none for deselecting non-selected one
                            expect(observer.capturedArguments).to(haveCount(1))
                        }
                    }

                    context("and there is selected marker") {
                        beforeEach {
                            random([
                                { sut.selectMarker(marker) },
                                { sut.handle(event: .didSelectMarker(marker, true)) }
                            ], using: &R)
                        }

                        it("should deselect it") {
                            sut.deselectAnyMarker()

                            expect(sut.selectedMarker).to(beNil())
                        }

                        it("should notify observer") {
                            sut.deselectAnyMarker()

                            expect(observer.capturedArgument?.markerSelection).to(beNil())
                        }
                    }
                }

                context("overlays") {
                    it("should notify observer about new state") {
                        let overlay = MapOverlay.circle(.init(coordinate: .random(using: &R), radius: .random(in: 0...100), lineWidth: 1))
                        sut.overlays = [overlay]

                        expect(observer.capturedArgument?.overlays).to(equal([overlay]))
                    }
                }

                context("zoom level") {
                    it("should notify observer about new state") {
                        sut.zoomLevel = 42

                        expect(observer.capturedArgument?.zoomLevel.value.zoom).to(equal(42))
                    }
                }

                context("center coordinate") {
                    it("should notify observer about new state") {
                        let coordinate = CLLocationCoordinate2D.random(using: &R)
                        sut.centerCoordinate = coordinate

                        expect(observer.capturedArgument?.centerCoordinate.value).to(equal(coordinate))
                    }
                }

                context("heading") {
                    it("should notify observer about new state") {
                        sut.heading = 42

                        expect(observer.capturedArgument?.heading.value).to(equal(42))
                    }
                }

                context("user tracking") {
                    it("should notify observer about new state") {
                        sut.isTrackingUser = false

                        expect(observer.capturedArgument?.isTrackingUser.value).to(beFalse())
                    }
                }

                context("cluster marker provider") {
                    it("should notify observer about new state") {
                        let provider = MapClusterMarkerProvider { MapClusterMarker(cluster: $0) }
                        sut.clusterMarkerProvider = provider

                        expect(observer.capturedArgument?.clusterMarkerProvider).to(equal(provider))
                    }
                }

                context("cluster configs provider") {
                    it("should notify observer about new state") {
                        let provider = MapClusterConfigsProvider { _ in MapClusterConfigs() }
                        sut.clusterConfigsProvider = provider

                        expect(observer.capturedArgument?.clusterConfigsProvider).to(equal(provider))
                    }
                }

                context("planned routes") {
                    var routes: [MapRoutePlan]!
                    var newRoutes: [MapRoutePlan]!
                    var fin: Result<MapRoutePlan.Response, NSError>!

                    beforeEach {
                        fin = .success(.random(using: &R))
                        routes = [MapRoutePlan].random(ofLength: 5, using: &R)
                        routes[2].status = .calculating
                        routes[4].status = .finished(fin)
                        routes[4].polylines = OrderedSet.random(ofLength: 3, using: &R)

                        sut.plannedRoutes = OrderedSet(routes)

                        newRoutes = [
                            .init(
                                source: routes[4].source,
                                destination: routes[4].destination,
                                transportType: routes[4].transportType,
                                renderWhen: routes[4].rendering,
                                polylinesProvider: .random(using: &R)
                            ),
                            .random(using: &R),
                            .random(using: &R),
                            .init(
                                source: routes[2].source,
                                destination: routes[2].destination,
                                transportType: routes[2].transportType,
                                renderWhen: routes[2].rendering,
                                polylinesProvider: .random(using: &R)
                            ),
                            .random(using: &R),
                            .random(using: &R)
                        ]
                    }

                    it("should set new routes and reuse existing routes by preserving new order") {
                        expect(newRoutes.map(\.status)).to(equal([.idle, .idle, .idle, .idle, .idle, .idle]))
                        expect(sut.plannedRoutes.map(\.status)).to(equal([.idle, .idle, .calculating, .idle, .finished(fin)]))

                        sut.plannedRoutes = OrderedSet(newRoutes)

                        expect(sut.plannedRoutes.map(\.status)).to(equal([.finished(fin), .idle, .idle, .calculating, .idle, .idle]))
                        expect(sut.plannedRoutes.first?.polylines).to(equal(routes[4].polylines))
                    }

                    it("should notify observer about new state") {
                        sut.plannedRoutes = OrderedSet(newRoutes)

                        expect(observer.capturedArgument?.plannedRoutes).to(equal(OrderedSet(newRoutes)))
                        expect(observer.capturedArgument?.plannedRoutes).to(equal(sut.plannedRoutes))
                    }
                }
            }
        }
    }
}

private enum MapContext {
    case any
}
