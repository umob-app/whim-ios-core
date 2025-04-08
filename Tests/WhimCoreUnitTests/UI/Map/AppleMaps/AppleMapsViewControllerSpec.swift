import Foundation
import Quick
import Nimble
@testable import WhimCore

final class AppleMapsViewControllerSpec: QuickSpec {
    override func spec() {
        describe("AppleMapsViewController") {
            var sut: AppleMapsViewController<MapContext>!
            var layerManager: MapLayerManager<MapContext>!

            beforeEach {
                layerManager = MapLayerManager()
                sut = AppleMapsViewController(layerManager: layerManager)
            }

            describe("when initialized") {
                it("should not be a layer manager delegate yet") {
                    expect(layerManager.delegate).to(beNil())
                }
            }

            describe("when no one else retains it") {
                it("should deallocate") {
                    weak var weakSUT: AppleMapsViewController<MapContext>?

                    autoreleasepool {
                        let vc = AppleMapsViewController(layerManager: layerManager)
                        vc.loadViewIfNeeded()

                        weakSUT = vc
                    }
                    expect(weakSUT).to(beNil())
                }
            }

            describe("when loaded view") {
                beforeEach {
                    sut.loadViewIfNeeded()
                }

                it("should become a layer manager delegate") {
                    expect(layerManager.delegate).toNot(beNil())
                }
            }
        }
    }
}

private enum MapContext {
    case any
}
