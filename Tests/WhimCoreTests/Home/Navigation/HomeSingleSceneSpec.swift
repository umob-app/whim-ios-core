import UIKit
import Quick
import Nimble

@testable import WhimCore

final class HomeSingleSceneSpec: QuickSpec {
    override func spec() {
        describe("HomeSingleScene") {
            describe("when created") {
                context("with home view controller") {
                    it("should store it") {
                        let homeViewController = HomeSceneViewController.fullscreen(UIViewController())
                        let sut = HomeSingleScene(homeViewController)

                        expect(sut.viewController).to(equal(homeViewController))
                    }

                    context("even if ui view controller belongs to other parent") {
                        it("should store it, keeping its ui parent") {
                            let parent = UIViewController()
                            let child = UIViewController()

                            parent.addChild(child)
                            parent.view.addSubview(child.view)
                            child.didMove(toParent: parent)

                            let homeViewController = HomeSceneViewController.fullscreen(child)
                            let sut = HomeSingleScene(homeViewController)

                            expect(sut.viewController).to(equal(homeViewController))
                            expect(sut.viewController.viewControllers.first?.parent).to(equal(parent))
                        }
                    }
                }

                context("with fullscreen view controller") {
                    it("should store it") {
                        let viewController = UIViewController()
                        let sut = HomeSingleScene(fullscreen: viewController)

                        expect(sut.viewController).to(equal(.fullscreen(viewController)))
                    }
                }

                context("with top and bottom view controllers") {
                    it("should store them") {
                        let topViewController = UIViewController()
                        let bottomViewController = UIViewController()
                        let sut = HomeSingleScene(top: topViewController, bottom: bottomViewController)

                        expect(sut.viewController).to(equal(.multipart(top: topViewController, bottom: bottomViewController)))
                    }
                }
            }

            describe("when asking for the next responder") {
                it("should be its parent") {
                    let sut = HomeSingleScene(fullscreen: UIViewController())
                    let parent = FakeSceneNavigationStack(sut)

                    expect(sut.relationship.parent).to(beIdenticalTo(parent))
                    expect(sut.nextSceneResponder).to(beIdenticalTo(parent))
                }
            }
        }
    }
}
