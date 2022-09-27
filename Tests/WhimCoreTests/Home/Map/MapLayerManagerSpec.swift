//import Foundation
//import CoreLocation
//import RxSwift
//import Quick
//import Nimble
//import SwiftyMock
//
//@testable import WhimCore
//
//final class MapLayerManagerSpec: QuickSpec {
//    override func spec() {
//        describe("MapLayerManager") {
//            var sut: MapLayerManager<MapContext>!
//
//            beforeEach {
//                sut = MapLayerManager()
//            }
//
//            describe("when assigning a new delegate") {
//                var delegate: FakeMapLayerManagerDelegate<MapContext>!
//
//                beforeEach {
//                    delegate = FakeMapLayerManagerDelegate()
//                }
//
//                context("with no layer being active at the moment") {
//                    it("should do nothing") {
//                        sut.delegate = .init(delegate)
//
//                        expect(delegate.didUpdateStateCall.called).to(beFalse())
//                    }
//                }
//
//                context("with active layer being present") {
//                    var layer: MapLayer<MapContext>!
//                    var lifetime: MapLayerLifetime!
//
//                    beforeEach {
//                        (layer, lifetime) = sut.registerNewLayer()
//                        layer.setCenter(.random(using: &R), zoomLevel: MapZoomLevel.random(using: &R), animated: false)
//                        sut.requestControlForLayer(with: layer.token)
//                    }
//
//                    it("should immediately update delegate with current active layer state") {
//                        sut.delegate = .init(delegate)
//
//                        expect(delegate.didUpdateStateCall.capturedArgument?.token).to(equal(layer.token))
//                        expect(layer.centerCoordinate).to(equal(delegate.didUpdateStateCall.capturedArgument?.state.centerCoordinate.value))
//                        expect(layer.zoomLevel).to(equal(delegate.didUpdateStateCall.capturedArgument?.state.zoomLevel.value))
//                    }
//                }
//            }
//
//            describe("when registering a new layer") {
//                var layer: MapLayer<MapContext>!
//                var lifetime: MapLayerLifetime!
//
//                beforeEach {
//                    (layer, lifetime) = sut.registerNewLayer(with: .one)
//                }
//
//                it("should have a unique token") {
//                    let otherLayers = (0 ..< 10).map { _ in sut.registerNewLayer() }
//                    let allTokens = [layer.token] + otherLayers.map(\.layer.token)
//
//                    expect(allTokens.isUnique).to(beTrue())
//                }
//
//                it("should have a valid lifetime") {
//                    expect(lifetime.isDisposed).to(beFalse())
//                }
//
//                it("should have given context") {
//                    expect(layer.context).to(equal(.one))
//                }
//
//                it("should not be active yet") {
//                    expect(layer.isActive).to(beFalse())
//                }
//
//                it("should store this layer") {
//                    expect(sut.hasLayer(with: layer.token)).to(beTrue())
//                }
//            }
//
//            describe("when requesting control for a layer") {
//                var layer: MapLayer<MapContext>!
//                var lifetime: MapLayerLifetime!
//                var delegate: FakeMapLayerManagerDelegate<MapContext>!
//
//                beforeEach {
//                    (layer, lifetime) = sut.registerNewLayer()
//                    delegate = FakeMapLayerManagerDelegate()
//                    sut.delegate = .init(delegate)
//                }
//
//                context("with invalid token") {
//                    var invalid: (layer: MapLayer<MapContext>, lifetime: MapLayerLifetime)!
//
//                    beforeEach {
//                        invalid = MapLayerManager<MapContext>().registerNewLayer()
//                    }
//
//                    it("should do nothing and return false") {
//                        let result = sut.requestControlForLayer(with: invalid.layer.token)
//
//                        expect(invalid.layer.isActive).to(beFalse())
//                        expect(sut.hasLayer(with: invalid.layer.token)).to(beFalse())
//                        expect(result).to(beFalse())
//                    }
//                }
//
//                context("with valid token") {
//                    var disposeBag: DisposeBag!
//
//                    beforeEach {
//                        disposeBag = DisposeBag()
//                    }
//
//                    it("should make this layer active and return true") {
//                        let result = sut.requestControlForLayer(with: layer.token)
//
//                        expect(layer.isActive).to(beTrue())
//                        expect(sut.hasLayer(with: layer.token)).to(beTrue())
//                        expect(result).to(beTrue())
//                    }
//
//                    it("should send corresponding event from that layer") {
//                        var receivedEvent: MapLayerEvent?
//                        layer.events.subscribe(onNext: { receivedEvent = $0 }).disposed(by: disposeBag)
//
//                        sut.requestControlForLayer(with: layer.token)
//
//                        expect(receivedEvent).to(equal(.didBecomeActive(true)))
//                    }
//                }
//
//                context("while having other previously active layer") {
//                    var otherLayer: MapLayer<MapContext>!
//                    var otherLifetime: MapLayerLifetime!
//
//                    beforeEach {
//                        (otherLayer, otherLifetime) = sut.registerNewLayer(with: .two)
//
//                        sut.requestControlForLayer(with: otherLayer.token)
//
//                        otherLayer.sidebar = .random(ofLength: 3, using: &R)
//                        otherLayer.configs = .random(ofLength: 3, using: &R)
//                        otherLayer.setCenter(.random(using: &R), zoomLevel: MapZoomLevel.random(using: &R), animated: false)
//                        otherLayer.setHeading(.random(in: 0...360, using: &R), animated: false)
//                        otherLayer.markers = .random(ofLength: 2, using: &R)
//                        otherLayer.overlays = .random(ofLength: 1, using: &R)
//                        otherLayer.isTrackingUser = false
//                        otherLayer.clusterMarkerProvider = MapClusterMarkerProvider.random(using: &R)
//                        otherLayer.clusterConfigsProvider = MapClusterConfigsProvider.random(using: &R)
//                    }
//
//                    context("and keeping its configs") {
//                        beforeEach {
//                            sut.requestControlForLayer(with: layer.token, transferFromPrevLayer: .init(position: .none, options: [.configs]))
//                        }
//
//                        it("should update new layer with only configs from the previous one") {
//                            expect(layer.configs).to(equal(otherLayer.configs))
//
//                            expect(layer.sidebar).toNot(equal(otherLayer.sidebar))
//                            expect(layer.centerCoordinate).toNot(equal(otherLayer.centerCoordinate))
//                            expect(layer.zoomLevel).toNot(equal(otherLayer.zoomLevel))
//                            expect(layer.heading).toNot(equal(otherLayer.heading))
//                            expect(layer.markers).toNot(equal(otherLayer.markers))
//                            expect(layer.overlays).toNot(equal(otherLayer.overlays))
//                            expect(layer.isTrackingUser).toNot(equal(otherLayer.isTrackingUser))
//                            expect(layer.clusterMarkerProvider).to(beNil())
//                            expect(layer.clusterConfigsProvider).to(beNil())
//                        }
//                    }
//
//                    context("and keeping its clustering") {
//                        beforeEach {
//                            sut.requestControlForLayer(with: layer.token, transferFromPrevLayer: .init(position: .none, options: [.clustering]))
//                        }
//
//                        it("should update new layer with only clustering configs and markers providers from the previous one") {
//                            expect(layer.clusterMarkerProvider).to(equal(otherLayer.clusterMarkerProvider))
//                            expect(layer.clusterConfigsProvider).to(equal(otherLayer.clusterConfigsProvider))
//
//                            expect(layer.configs).toNot(equal(otherLayer.configs))
//                            expect(layer.sidebar).toNot(equal(otherLayer.sidebar))
//                            expect(layer.centerCoordinate).toNot(equal(otherLayer.centerCoordinate))
//                            expect(layer.zoomLevel).toNot(equal(otherLayer.zoomLevel))
//                            expect(layer.heading).toNot(equal(otherLayer.heading))
//                            expect(layer.markers).toNot(equal(otherLayer.markers))
//                            expect(layer.overlays).toNot(equal(otherLayer.overlays))
//                            expect(layer.isTrackingUser).toNot(equal(otherLayer.isTrackingUser))
//                        }
//                    }
//
//                    context("and keeping its relative position") {
//                        beforeEach {
//                            sut.requestControlForLayer(with: layer.token, transferFromPrevLayer: .init(position: .relative))
//                        }
//
//                        it("should update new layer with only position from the previous one and drop userTracking") {
//                            expect(layer.centerCoordinate).to(equal(otherLayer.centerCoordinate))
//                            expect(layer.zoomLevel).to(equal(otherLayer.zoomLevel))
//                            expect(layer.heading).to(equal(otherLayer.heading))
//                            expect(layer.isTrackingUser).to(beFalse())
//
//                            expect(layer.configs).toNot(equal(otherLayer.configs))
//                            expect(layer.sidebar).toNot(equal(otherLayer.sidebar))
//                            expect(layer.markers).toNot(equal(otherLayer.markers))
//                            expect(layer.overlays).toNot(equal(otherLayer.overlays))
//                            expect(layer.clusterMarkerProvider).to(beNil())
//                            expect(layer.clusterConfigsProvider).to(beNil())
//                        }
//                    }
//
//                    context("and keeping its absolute position") {
//                        beforeEach {
//                            sut.requestControlForLayer(with: layer.token, transferFromPrevLayer: .init(position: .absolute))
//                        }
//
//                        it("should update new layer with default coordinate but zoom from the previous one and drop userTracking") {
//                            expect(layer.centerCoordinate).to(equal(MapLayerState.defaultCenterCoordinate))
//                            expect(layer.zoomLevel).to(equal(otherLayer.zoomLevel))
//                            expect(layer.heading).to(equal(otherLayer.heading))
//                            expect(layer.isTrackingUser).to(beFalse())
//
//                            expect(layer.configs).toNot(equal(otherLayer.configs))
//                            expect(layer.sidebar).toNot(equal(otherLayer.sidebar))
//                            expect(layer.markers).toNot(equal(otherLayer.markers))
//                            expect(layer.overlays).toNot(equal(otherLayer.overlays))
//                            expect(layer.clusterMarkerProvider).to(beNil())
//                            expect(layer.clusterConfigsProvider).to(beNil())
//                        }
//                    }
//
//                    context("and keeping only its coordinate") {
//                        beforeEach {
//                            sut.requestControlForLayer(with: layer.token, transferFromPrevLayer: .init(position: .coordinateOnly))
//                        }
//
//                        it("should update new layer with previous coordinate and keep everything else to itself") {
//                            expect(layer.centerCoordinate).to(equal(otherLayer.centerCoordinate))
//
//                            expect(layer.zoomLevel).toNot(equal(otherLayer.zoomLevel))
//                            expect(layer.heading).toNot(equal(otherLayer.heading))
//                            expect(layer.isTrackingUser).to(beFalse())
//                            expect(layer.configs).toNot(equal(otherLayer.configs))
//                            expect(layer.sidebar).toNot(equal(otherLayer.sidebar))
//                            expect(layer.markers).toNot(equal(otherLayer.markers))
//                            expect(layer.overlays).toNot(equal(otherLayer.overlays))
//                            expect(layer.clusterMarkerProvider).to(beNil())
//                            expect(layer.clusterConfigsProvider).to(beNil())
//                        }
//                    }
//
//                    context("and keeping its sidebar and user tracking (without markers and overlays for now)") {
//                        beforeEach {
//                            sut.requestControlForLayer(
//                                with: layer.token,
//                                transferFromPrevLayer: .init(position: .none, options:  [.sidebar, /*.markers, .overlays,*/ .userTracking])
//                            )
//                        }
//
//                        it("should update new layer with only position from the previous one") {
//                            expect(layer.sidebar).to(equal(otherLayer.sidebar))
//                            expect(layer.isTrackingUser).to(equal(otherLayer.isTrackingUser))
//
//                            // TODO: MAP `markers, overlays` - temporary disabled until AppleMapsViewController is unit-tested and can be safely extended
//                            expect(layer.markers).toNot(equal(otherLayer.markers))
//                            expect(layer.overlays).toNot(equal(otherLayer.overlays))
//
//                            expect(layer.configs).toNot(equal(otherLayer.configs))
//                            expect(layer.centerCoordinate).toNot(equal(otherLayer.centerCoordinate))
//                            expect(layer.zoomLevel).toNot(equal(otherLayer.zoomLevel))
//                            expect(layer.heading).toNot(equal(otherLayer.heading))
//                            expect(layer.clusterMarkerProvider).to(beNil())
//                            expect(layer.clusterConfigsProvider).to(beNil())
//                        }
//                    }
//
//                    context("and ignoring any of its properties") {
//                        beforeEach {
//                            sut.requestControlForLayer(with: layer.token, transferFromPrevLayer: .none)
//                        }
//
//                        it("should not update new layer at all") {
//                            expect(layer.configs).toNot(equal(otherLayer.configs))
//                            expect(layer.sidebar).toNot(equal(otherLayer.sidebar))
//                            expect(layer.centerCoordinate).toNot(equal(otherLayer.centerCoordinate))
//                            expect(layer.zoomLevel).toNot(equal(otherLayer.zoomLevel))
//                            expect(layer.heading).toNot(equal(otherLayer.heading))
//                            expect(layer.markers).toNot(equal(otherLayer.markers))
//                            expect(layer.overlays).toNot(equal(otherLayer.overlays))
//                            expect(layer.isTrackingUser).toNot(equal(otherLayer.isTrackingUser))
//                            expect(layer.clusterMarkerProvider).to(beNil())
//                            expect(layer.clusterConfigsProvider).to(beNil())
//                        }
//                    }
//
//                    context("and dynamically deciding what properties to transfer based on previous layer context") {
//                        beforeEach {
//                            sut.requestControlForLayer(with: layer.token, transferFromPrevLayer: { ctx in
//                                switch ctx {
//                                case .two: return .init(position: .coordinateOnly)
//                                default: return .none
//                                }
//                            })
//                        }
//
//                        it("should transfer only chosen properties") {
//                            expect(layer.centerCoordinate).to(equal(otherLayer.centerCoordinate))
//
//                            expect(layer.zoomLevel).toNot(equal(otherLayer.zoomLevel))
//                            expect(layer.heading).toNot(equal(otherLayer.heading))
//                            expect(layer.isTrackingUser).to(beFalse())
//                            expect(layer.configs).toNot(equal(otherLayer.configs))
//                            expect(layer.sidebar).toNot(equal(otherLayer.sidebar))
//                            expect(layer.markers).toNot(equal(otherLayer.markers))
//                            expect(layer.overlays).toNot(equal(otherLayer.overlays))
//                            expect(layer.clusterMarkerProvider).to(beNil())
//                            expect(layer.clusterConfigsProvider).to(beNil())
//                        }
//                    }
//
//                    it("should notify delegate of a new layer activation") {
//                        sut.requestControlForLayer(with: layer.token)
//
//                        expect(delegate.didActivateLayerWithTokenCall.capturedArgument?.token).to(equal(layer.token))
//                    }
//
//                    it("should make other layer inactive") {
//                        sut.requestControlForLayer(with: layer.token)
//
//                        expect(otherLayer.isActive).to(beFalse())
//                    }
//                }
//
//                context("while not having any previously active layer") {
//                    beforeEach {
//                        sut.requestControlForLayer(with: layer.token)
//                    }
//
//                    it("should notify delegate of a new layer activation") {
//                        expect(delegate.didActivateLayerWithTokenCall.capturedArgument?.token).to(equal(layer.token))
//                    }
//                }
//
//                context("for the same active layer") {
//                    beforeEach {
//                        sut.requestControlForLayer(with: layer.token)
//                    }
//
//                    it("should return true and do nothing") {
//                        let result = sut.requestControlForLayer(with: layer.token)
//
//                        expect(result).to(beTrue())
//                        // only one call for the first time it was activated inside `context.beforeEach` above
//                        expect(delegate.didActivateLayerWithTokenCall.callsCount).to(equal(1))
//                        expect(delegate.didRelinquishActiveLayerCall.callsCount).to(equal(0))
//                    }
//                }
//            }
//
//            describe("when relinquishing control for a layer") {
//                var layer: MapLayer<MapContext>!
//                var lifetime: MapLayerLifetime!
//                var delegate: FakeMapLayerManagerDelegate<MapContext>!
//
//                beforeEach {
//                    (layer, lifetime) = sut.registerNewLayer()
//                    delegate = FakeMapLayerManagerDelegate()
//                    sut.delegate = .init(delegate)
//                }
//
//                context("with invalid token") {
//                    var invalid: (layer: MapLayer<MapContext>, lifetime: MapLayerLifetime)!
//
//                    beforeEach {
//                        invalid = MapLayerManager().registerNewLayer()
//                    }
//
//                    it("should do nothing and return false") {
//                        let result = sut.relinquishControlForLayer(with: invalid.layer.token)
//
//                        expect(invalid.layer.isActive).to(beFalse())
//                        expect(sut.hasLayer(with: invalid.layer.token)).to(beFalse())
//                        expect(result).to(beFalse())
//                    }
//                }
//
//                context("with valid token") {
//                    context("when layer is active") {
//                        var disposeBag: DisposeBag!
//
//                        beforeEach {
//                            disposeBag = DisposeBag()
//
//                            sut.requestControlForLayer(with: layer.token)
//                        }
//
//                        it("should make this layer inactive and return true") {
//                            let result = sut.relinquishControlForLayer(with: layer.token)
//
//                            expect(layer.isActive).to(beFalse())
//                            expect(result).to(beTrue())
//                        }
//
//                        it("should notify delegate of relinquishing active layer") {
//                            sut.relinquishControlForLayer(with: layer.token)
//
//                            expect(delegate.didRelinquishActiveLayerCall.capturedArgument?.token).to(equal(layer.token))
//                        }
//
//                        it("should send corresponding event from that layer") {
//                            var receivedEvent: MapLayerEvent?
//                            layer.events.subscribe(onNext: { receivedEvent = $0 }).disposed(by: disposeBag)
//
//                            sut.relinquishControlForLayer(with: layer.token)
//
//                            expect(receivedEvent).to(equal(.didBecomeActive(false)))
//                        }
//                    }
//
//                    context("when layer is not active") {
//                        var disposeBag: DisposeBag!
//
//                        beforeEach {
//                            disposeBag = DisposeBag()
//                        }
//
//                        it("should not notify delegate of relinquishing active layer and return true") {
//                            let result = sut.relinquishControlForLayer(with: layer.token)
//
//                            expect(result).to(beTrue())
//                            expect(delegate.didRelinquishActiveLayerCall.called).to(beFalse())
//                        }
//
//                        it("should not send any event from that layer") {
//                            var receivedEvent: MapLayerEvent?
//                            layer.events.subscribe(onNext: { receivedEvent = $0 }).disposed(by: disposeBag)
//
//                            sut.relinquishControlForLayer(with: layer.token)
//
//                            expect(receivedEvent).to(beNil())
//                        }
//                    }
//
//                    it("should not remove this layer") {
//                        sut.relinquishControlForLayer(with: layer.token)
//
//                        expect(sut.hasLayer(with: layer.token)).to(beTrue())
//                    }
//
//                    it("should not make any other layer active automatically") {
//                        sut.requestControlForLayer(with: layer.token)
//
//                        let otherLayers = (0 ..< 10).map { _ in sut.registerNewLayer() }
//
//                        sut.relinquishControlForLayer(with: layer.token)
//
//                        expect(otherLayers.map(\.layer.isActive)).to(allPass(beFalse()))
//                    }
//                }
//
//                context("and requesting it back again") {
//                    beforeEach {
//                        sut.requestControlForLayer(with: layer.token)
//                        sut.relinquishControlForLayer(with: layer.token)
//                    }
//
//                    it("should make this layer active again and return true") {
//                        let result = sut.requestControlForLayer(with: layer.token)
//
//                        expect(result).to(beTrue())
//                        expect(layer.isActive).to(beTrue())
//                    }
//                }
//            }
//
//            describe("when handling map event") {
//                var layer: MapLayer<MapContext>!
//                var lifetime: MapLayerLifetime!
//                var delegate: FakeMapLayerManagerDelegate<MapContext>!
//
//                var event: MapEvent!
//                var newLocation: CLLocationCoordinate2D!
//                var newZoom: Double!
//                var newHeading: CLLocationDirection!
//
//                var disposeBag: DisposeBag!
//
//                beforeEach {
//                    (layer, lifetime) = sut.registerNewLayer()
//                    delegate = FakeMapLayerManagerDelegate()
//                    sut.delegate = .init(delegate)
//
//                    newLocation = CLLocationCoordinate2D.random(using: &R)
//                    newZoom = Double.random(in: MapZoomLevel.minZoomLevel...MapZoomLevel.maxZoomLevel, using: &R)
//                    newHeading = CLLocationDirection.random(in: 0...360, using: &R)
//                    event = .changingPosition(status: .ended, center: newLocation, zoom: newZoom, heading: newHeading, span: .random(using: &R))
//
//                    disposeBag = DisposeBag()
//                }
//
//                context("with layer being removed") {
//                    beforeEach {
//                        lifetime.dispose()
//                    }
//
//                    it("should not send event") {
//                        var receivedEvent: MapLayerEvent?
//                        layer.events.subscribe(onNext: { receivedEvent = $0 }).disposed(by: disposeBag)
//
//                        sut.handle(event: event, for: layer.token)
//
//                        expect(receivedEvent).to(beNil())
//                    }
//
//                    it("should not change layer") {
//                        sut.handle(event: event, for: layer.token)
//
//                        expect(layer.centerCoordinate).toNot(equal(newLocation))
//                        expect(layer.zoomLevel.zoom).toNot(equal(newZoom))
//                        expect(layer.heading).toNot(equal(newHeading))
//                    }
//                }
//
//                context("with layer not being active at the moment") {
//                    it("should not send event") {
//                        var receivedEvent: MapLayerEvent?
//                        layer.events.subscribe(onNext: { receivedEvent = $0 }).disposed(by: disposeBag)
//
//                        sut.handle(event: event, for: layer.token)
//
//                        expect(receivedEvent).to(beNil())
//                    }
//
//                    it("should not change layer") {
//                        sut.handle(event: event, for: layer.token)
//
//                        expect(layer.centerCoordinate).toNot(equal(newLocation))
//                        expect(layer.zoomLevel.zoom).toNot(equal(newZoom))
//                        expect(layer.heading).toNot(equal(newHeading))
//                    }
//                }
//
//                context("with active layer being present") {
//                    beforeEach {
//                        sut.requestControlForLayer(with: layer.token)
//                    }
//
//                    it("should deliver this event to it") {
//                        var receivedEvent: MapLayerEvent?
//                        layer.events.subscribe(onNext: { receivedEvent = $0 }).disposed(by: disposeBag)
//
//                        sut.handle(event: event, for: layer.token)
//
//                        expect(receivedEvent).to(equal(.map(event)))
//                    }
//
//                    it("should change layer based on the event") {
//                        sut.handle(event: event, for: layer.token)
//
//                        expect(layer.centerCoordinate).to(equal(newLocation))
//                        expect(layer.zoomLevel.zoom).to(equal(newZoom))
//                        expect(layer.heading).to(equal(newHeading))
//                    }
//                }
//            }
//
//            describe("when layer lifetime is disposed") {
//                var layer: MapLayer<MapContext>!
//                var lifetime: MapLayerLifetime!
//                var delegate: FakeMapLayerManagerDelegate<MapContext>!
//
//                beforeEach {
//                    (layer, lifetime) = sut.registerNewLayer()
//
//                    sut.requestControlForLayer(with: layer.token)
//                }
//
//                context("by deinitializing it") {
//                    beforeEach {
//                        delegate = FakeMapLayerManagerDelegate()
//                        sut.delegate = .init(delegate)
//
//                        lifetime = nil
//                    }
//
//                    it("should make the layer inactive") {
//                        expect(layer.isActive).to(beFalse())
//                    }
//
//                    it("should remove the layer") {
//                        expect(sut.hasLayer(with: layer.token)).to(beFalse())
//                    }
//
//                    it("should notify delegate of relinquishing this layer") {
//                        expect(delegate.didRelinquishActiveLayerCall.capturedArgument?.token).to(equal(layer.token))
//                    }
//                }
//
//                context("manually") {
//                    beforeEach {
//                        delegate = FakeMapLayerManagerDelegate()
//                        sut.delegate = .init(delegate)
//
//                        lifetime.dispose()
//                    }
//
//                    it("should have disposed lifetime") {
//                        expect(lifetime.isDisposed).to(beTrue())
//                    }
//
//                    it("should make the layer inactive") {
//                        expect(layer.isActive).to(beFalse())
//                    }
//
//                    it("should remove the layer") {
//                        expect(sut.hasLayer(with: layer.token)).to(beFalse())
//                    }
//
//                    it("should notify delegate of relinquishing control for this layer") {
//                        expect(delegate.didRelinquishActiveLayerCall.capturedArgument?.token).to(equal(layer.token))
//                    }
//                }
//
//                context("and then trying to request control for its token") {
//                    beforeEach {
//                        lifetime = nil
//
//                        delegate = FakeMapLayerManagerDelegate()
//                        sut.delegate = .init(delegate)
//                    }
//
//                    it("should do nothing and return false") {
//                        let result = sut.requestControlForLayer(with: layer.token)
//
//                        expect(result).to(beFalse())
//                        expect(delegate.didUpdateStateCall.called).to(beFalse())
//                    }
//                }
//
//                context("and then trying to relinquish control for its token") {
//                    beforeEach {
//                        lifetime = nil
//
//                        delegate = FakeMapLayerManagerDelegate()
//                        sut.delegate = .init(delegate)
//                    }
//
//                    it("should do nothing and return false") {
//                        let result = sut.relinquishControlForLayer(with: layer.token)
//
//                        expect(result).to(beFalse())
//                        expect(delegate.didRelinquishActiveLayerCall.called).to(beFalse())
//                    }
//                }
//            }
//        }
//    }
//}
//
//private enum MapContext {
//    case one, two
//}
//
//private extension Sequence where Element: Hashable {
//    var isUnique: Bool {
//        var seen = Set<Element>()
//        return allSatisfy { seen.insert($0).inserted }
//    }
//}
