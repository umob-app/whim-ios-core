import Foundation
import Quick
import Nimble
import CoreLocation
import RxSwift
import RxRelay
import SwiftyMock
import WhimRandom

@testable import WhimCore

final class MapLayerSpec: QuickSpec {
    override func spec() {
        describe("MapLayer") {
            var sut: MapLayer<MapContext>!
            var observer: FunctionCall<MapLayerState, Void>!

            beforeEach {
                observer = FunctionCall()
                sut = MapLayerManager.testLayer { [weak observer] state in
                    observer.map { stubCall($0, argument: state, defaultValue: ()) }
                }
            }

            describe("when initialized") {
                it("should have default state") {
                    expect(sut.state).to(equal(.default))
                }
            }

            describe("when handling event") {
                it("should be sent through observable events") {
                    let event = MapEvent.random(using: &R)
                    var receivedEvent: MapLayerEvent?
                    _ = sut.events.take(1).bind(onNext: { event in
                        receivedEvent = event
                    })

                    sut.handle(event: event)
                    expect(receivedEvent?.map).to(equal(event))
                }

                context("of changing position") {
                    context("starting") {
                        it("should ignore it") {
                            let originalCoordinate = sut.centerCoordinate
                            let originalZoom = sut.zoomLevel
                            let originalHeading = sut.heading
                            sut.handle(event: .changingPosition(status: .starting, center: .random(using: &R), zoom: 10, heading: 42, span: .random(using: &R)))

                            expect(observer.capturedArgument).to(beNil())
                            expect(sut.centerCoordinate).to(equal(originalCoordinate))
                            expect(sut.zoomLevel).to(equal(originalZoom))
                            expect(sut.heading).to(equal(originalHeading))
                        }
                    }

                    context("in progress") {
                        it("should update it without notifying observer") {
                            let newCoordinate = CLLocationCoordinate2D.random(using: &R)
                            sut.handle(event: .changingPosition(status: .inProgress, center: newCoordinate, zoom: 10, heading: 42, span: .random(using: &R)))

                            expect(observer.capturedArgument).to(beNil())
                            expect(sut.centerCoordinate).to(equal(newCoordinate))
                            expect(sut.zoomLevel).to(equal(.zoom(10)))
                            expect(sut.heading).to(equal(42))
                        }
                    }

                    context("ended") {
                        it("should update it without notifying observer") {
                            let newCoordinate = CLLocationCoordinate2D.random(using: &R)
                            sut.handle(event: .changingPosition(status: .ended, center: newCoordinate, zoom: 10, heading: 42, span: .random(using: &R)))

                            expect(observer.capturedArgument).to(beNil())
                            expect(sut.centerCoordinate).to(equal(newCoordinate))
                            expect(sut.zoomLevel).to(equal(.zoom(10)))
                            expect(sut.heading).to(equal(42))
                        }
                    }
                }

                context("of updating visible rect inset") {
                    it("should update it without notifying observer") {
                        sut.handle(event: .didUpdateVisibleRectInset(.custom(bottom: 42)))

                        expect(observer.capturedArgument).to(beNil())
                        expect(sut.visibleRectInset.bottom.value).to(equal(42))
                    }
                }

                context("of updating user tracking") {
                    it("should update it without notifying observer") {
                        sut.handle(event: .didUpdateUserTracking(false))

                        expect(observer.capturedArgument).to(beNil())
                        expect(sut.isTrackingUser).to(beFalse())
                    }
                }

                context("of tapping sidebar item") {
                    context("to track user") {
                        it("should turn on user tracking and notify observer") {
                            sut.handle(event: .didTapSidebarItem(.trackUser(highlightedContent: nil, normalContent: nil)))

                            expect(observer.capturedArgument?.isTrackingUser.value).to(beTrue())
                            expect(sut.isTrackingUser).to(beTrue())
                        }
                    }

                    context("other") {
                        var customItem: MapSidebarItem!

                        beforeEach {
                            customItem = .custom(.random(using: &R))
                            sut.sidebar = [.trackUser(highlightedContent: nil, normalContent: nil), customItem]
                        }

                        it("should ignore it") {
                            sut.handle(event: .didTapSidebarItem(customItem))

                            // only one observer event for setting sidebar, and none for tapping custom item
                            expect(observer.capturedArguments).to(haveCount(1))
                        }
                    }
                }

                context("of tapping at coordinate") {
                    it("should ignore it") {
                        sut.handle(event: .didTap(.random(using: &R)))

                        expect(observer.capturedArguments).to(beEmpty())
                    }
                }

                context("of tapping inside overlay") {
                    var overlay: MapOverlay!

                    beforeEach {
                        overlay = MapOverlay.circle(.init(coordinate: .random(using: &R), radius: 42, lineWidth: 2))
                        sut.overlays = [overlay]
                    }

                    it("should ignore it") {
                        sut.handle(event: .didTapInsideOverlay(overlay, .random(using: &R)))

                        // only one observer event for setting overlays, and none for tapping overlay
                        expect(observer.capturedArguments).to(haveCount(1))
                    }
                }

                context("of selecting marker") {
                    var marker: MapMarker!

                    beforeEach {
                        marker = MapMarker.random(using: &R)
                        sut.markers = [marker]
                    }

                    context("having it in selecting state") {
                        beforeEach {
                            sut.selectMarker(marker)
                        }

                        it("should switch it into selected state") {
                            sut.handle(event: .didSelectMarker(marker, true))

                            expect(sut.selectedMarker?.isSelected).to(beTrue())
                        }
                    }

                    context("not having it in any prior state") {
                        it("should set it into selected state") {
                            sut.handle(event: .didSelectMarker(marker, true))

                            expect(sut.selectedMarker?.isSelected).to(beTrue())
                        }
                    }
                }

                context("of deselecting marker") {
                    var marker: MapMarker!

                    beforeEach {
                        marker = MapMarker.random(using: &R)
                        sut.markers = [marker]
                    }

                    context("having it selected") {
                        beforeEach {
                            random([
                                { sut.selectMarker(marker) },
                                { sut.handle(event: .didSelectMarker(marker, true)) }
                            ], using: &R)
                        }

                        it("should remove its selected state") {
                            sut.handle(event: .didSelectMarker(marker, false))

                            expect(sut.selectedMarker).to(beNil())
                            expect(sut.markers).to(equal([marker]))
                        }
                    }

                    context("having other marker selected") {
                        var other: MapMarker!

                        beforeEach {
                            other = MapMarker.random(using: &R)
                            sut.markers.insert(other)

                            random([
                                { sut.selectMarker(other) },
                                { sut.handle(event: .didSelectMarker(other, true)) }
                            ], using: &R)
                        }

                        it("should keep other marker selected") {
                            sut.handle(event: .didSelectMarker(marker, false))

                            expect(sut.selectedMarker?.value).to(equal(other))
                        }
                    }

                    context("not having it in any prior state") {
                        it("should do nothing") {
                            sut.handle(event: .didSelectMarker(marker, false))

                            expect(sut.selectedMarker).to(beNil())
                        }
                    }
                }

                context("of tapping on cluster") {
                    var cluster: MapClusterMarker!

                    beforeEach {
                        let marker = MapMarker(coordinate: .random(using: &R), clusteringIdentifier: "abc")
                        cluster = MapClusterMarker(cluster: .makeDefault(identifier: "abc", items: [marker]))
                        sut.markers = [marker]
                    }

                    it("should ignore it") {
                        sut.handle(event: .didTapOnCluster(cluster))

                        // only one observer event for setting markers, and none for tapping cluster
                        expect(observer.capturedArguments).to(haveCount(1))
                    }
                }

                context("of planned routes") {
                    beforeEach {
                        sut.plannedRoutes = .random(ofLength: 3, using: &R)
                    }

                    context("once started calculating") {
                        var started: [MapRoutePlan]! 

                        beforeEach {
                            started = [sut.plannedRoutes[1], sut.plannedRoutes[2], .random(using: &R)]
                            sut.handle(event: .didStartCalculatingRoutes(started))
                        }

                        it("should update routes that belong to the layer and notify observer") {
                            expect(sut.plannedRoutes.map(\.status)).to(equal([.idle, .calculating, .calculating]))

                            // one observer event for setting planned routes, and second one for handling event
                            expect(observer.capturedArguments).to(haveCount(2))
                        }
                    }

                    context("once finished calculating") {
                        var succ: Result<MapRoutePlan.Response, NSError>!
                        var fail: Result<MapRoutePlan.Response, NSError>!
                        var finished: [MapRoutePlan: Result<MapRoutePlan.Response, NSError>]!

                        beforeEach {
                            succ = .success(.random(using: &R))
                            fail = .failure(.random(using: &R))
                            finished = [sut.plannedRoutes[1]: succ, sut.plannedRoutes[2]: fail, .random(using: &R): .success(.random(using: &R))]
                            sut.handle(event: .didFinishCalculatingRoutes(finished))
                        }

                        it("should update routes that belong to the layer and construct polylines for them only and notify observer") {
                            expect(sut.plannedRoutes.map(\.status)).to(equal([.idle, .finished(succ), .finished(fail)]))

                            expect(sut.plannedRoutes.map(\.polylines)[0]).to(beNil())
                            expect(sut.plannedRoutes.map(\.polylines)[1]).toNot(beNil())
                            expect(sut.plannedRoutes.map(\.polylines)[2]).to(beNil())

                            // one observer event for setting planned routes, and second one for handling event
                            expect(observer.capturedArguments).to(haveCount(2))
                        }
                    }
                }
            }
        }
    }
}

private enum MapContext {
    case any
}
