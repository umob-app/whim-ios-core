import UIKit
import Quick
import Nimble

@testable import WhimCore

final class WhimSingleSceneSpec: QuickSpec {
    override func spec() {
        describe("WhimSingleScene") {
            describe("when created") {
                context("with whim view controller") {
                    it("should store it") {
                        let whimViewController = WhimSceneViewController.fullscreen(UIViewController())
                        let sut = WhimSingleScene(whimViewController)

                        expect(sut.viewController).to(equal(whimViewController))
                    }

                    context("even if ui view controller belongs to other parent") {
                        it("should store it, keeping its ui parent") {
                            let parent = UIViewController()
                            let child = UIViewController()

                            parent.addChild(child)
                            parent.view.addSubview(child.view)
                            child.didMove(toParent: parent)

                            let whimViewController = WhimSceneViewController.fullscreen(child)
                            let sut = WhimSingleScene(whimViewController)

                            expect(sut.viewController).to(equal(whimViewController))
                            expect(sut.viewController.viewControllers.first?.parent).to(equal(parent))
                        }
                    }
                }

                context("with fullscreen view controller") {
                    it("should store it") {
                        let viewController = UIViewController()
                        let sut = WhimSingleScene(fullscreen: viewController)

                        expect(sut.viewController).to(equal(.fullscreen(viewController)))
                    }
                }

                context("with top and bottom view controllers") {
                    it("should store them") {
                        let topViewController = UIViewController()
                        let bottomViewController = UIViewController()
                        let sut = WhimSingleScene(top: topViewController, bottom: bottomViewController)

                        expect(sut.viewController).to(equal(.multipart(top: topViewController, bottom: bottomViewController)))
                    }
                }
            }

            describe("when asking for the next responder") {
                it("should be its parent") {
                    let sut = WhimSingleScene(fullscreen: UIViewController())
                    let parent = FakeSceneNavigationStack(sut)

                    expect(sut.relationship.parent).to(beIdenticalTo(parent))
                    expect(sut.nextSceneResponder).to(beIdenticalTo(parent))
                }
            }
        }
    }
}
