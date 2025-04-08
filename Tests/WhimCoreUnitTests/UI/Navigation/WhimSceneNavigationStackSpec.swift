import UIKit
import Quick
import Nimble
import SwiftyMock

@testable import WhimCore

// swiftlint:disable superfluous_disable_command file_length function_body_length unused_closure_parameter compiler_protocol_init

final class WhimSceneNavigationStackSpec: QuickSpec {
    override func spec() {
        describe("WhimSceneNavigationStack") {
            describe("when initialized") {
                it("should have no parent or responder") {
                    let sut = WhimSceneNavigationStack(WhimSingleScene(fullscreen: UIViewController()))

                    expect(sut.relationship.parent).to(beNil())
                    expect(sut.nextSceneResponder).to(beNil())
                }

                // TODO: CwlPreconditionTesting - Support Apple Silicon: https://github.com/mattgallagher/CwlPreconditionTesting/issues/21
                #if arch(x86_64)
                context("with empty scenes array") {
                    it("should create empty stack and not crash") {
                        expect { _ = WhimSceneNavigationStack([]) }.toNot(throwAssertion())
                        expect(WhimSceneNavigationStack([]).scenes).to(beEmpty())
                    }
                }

                context("with all scenes belonging to other parent scene") {
                    it("should create empty stack and not crash") {
                        let scene = WhimSingleScene(fullscreen: UIViewController())
                        let otherParent = WhimSceneNavigationStack(scene)

                        expect { _ = WhimSceneNavigationStack(scene) }.toNot(throwAssertion())
                        expect(WhimSceneNavigationStack(scene).scenes).to(beEmpty())
                    }
                }
                #endif

                context("with some scenes belonging to other parent scene") {
                    it("should add only those scenes that don't belong to anyone and keep correct order") {
                        let scene1 = WhimSingleScene(fullscreen: UIViewController())
                        let scene2 = WhimSingleScene(fullscreen: UIViewController())
                        let scene3 = WhimSingleScene(fullscreen: UIViewController())
                        let scene4 = WhimSingleScene(fullscreen: UIViewController())
                        let otherParent = WhimSceneNavigationStack(scene1, scene2)
                        let sut = WhimSceneNavigationStack(scene1, scene2, scene3, scene4)

                        expect(sut.scenes).to(haveCount(2))
                        expect(sut.scenes[0]).to(beIdenticalTo(scene3))
                        expect(sut.scenes[1]).to(beIdenticalTo(scene4))
                    }
                }
            }

            describe("when asking for the next responder") {
                it("should be its parent") {
                    let sut = WhimSceneNavigationStack(WhimSingleScene(fullscreen: UIViewController()))
                    let parent = FakeSceneNavigationStack(sut)

                    expect(sut.relationship.parent).to(beIdenticalTo(parent))
                    expect(sut.nextSceneResponder).to(beIdenticalTo(parent))
                }
            }

            describe("when asking for the view controller") {
                context("with an empty stack") {
                    it("should return fullscreen white placeholder view controller") {
                        expect(WhimSceneNavigationStack([]).viewController.fullscreen?.view.backgroundColor).to(equal(.white))
                    }
                }

                it("should be the one from the top of the stack") {
                    let topViewController = UIViewController()
                    let sut = WhimSceneNavigationStack(
                        WhimSingleScene(fullscreen: UIViewController()),
                        WhimSingleScene(fullscreen: UIViewController()),
                        WhimSingleScene(fullscreen: topViewController)
                    )

                    expect(sut.viewController).to(equal(.fullscreen(topViewController)))
                }

                context("having another navigation stack on the top of the stack") {
                    it("should be the one from its top of the stack, no matter how deeply nested it is") {
                        let topViewController = UIViewController()
                        let sut = WhimSceneNavigationStack(
                            WhimSingleScene(fullscreen: UIViewController()),
                            WhimSingleScene(fullscreen: UIViewController()),
                            WhimSceneNavigationStack(
                                WhimSceneNavigationStack(
                                    WhimSceneNavigationStack(
                                        WhimSingleScene(fullscreen: UIViewController()),
                                        WhimSingleScene(fullscreen: topViewController)
                                    )
                                )
                            )
                        )

                        expect(sut.viewController).to(equal(.fullscreen(topViewController)))
                    }
                }
            }

            describe("when pushing a scene") {
                context("which has other parent") {
                    var scene: WhimSingleScene!
                    var otherParent: WhimSceneNavigationStack!
                    var rootScene: WhimSingleScene!
                    var sut: WhimSceneNavigationStack!

                    beforeEach {
                        scene = WhimSingleScene(fullscreen: UIViewController())
                        otherParent = WhimSceneNavigationStack(scene)
                        rootScene = WhimSingleScene(fullscreen: UIViewController())
                        sut = WhimSceneNavigationStack(rootScene)

                        sut.push(scene: scene)
                    }

                    it("should not add it") {
                        expect(sut.scenes).to(haveCount(1))
                        expect(sut.scenes.first).to(beIdenticalTo(rootScene))
                    }

                    it("should keep child to its original parent") {
                        expect(scene.relationship.parent).to(beIdenticalTo(otherParent))
                    }
                }

                context("which has same parent") {
                    it("should not add it again") {
                        let scene = WhimSingleScene(fullscreen: UIViewController())
                        let sut = WhimSceneNavigationStack(scene)

                        sut.push(scene: scene)

                        expect(sut.scenes).to(haveCount(1))
                        expect(sut.scenes.first).to(beIdenticalTo(scene))
                    }
                }

                context("which doesn't belong to other parent") {
                    var rootScene: WhimSingleScene!
                    var sut: WhimSceneNavigationStack!
                    var scene: WhimSingleScene!
                    var sceneViewController: UIViewController!

                    beforeEach {
                        rootScene = WhimSingleScene(fullscreen: UIViewController())
                        sut = WhimSceneNavigationStack(rootScene)
                        sceneViewController = UIViewController()
                        scene = WhimSingleScene(fullscreen: sceneViewController)
                    }

                    context("and its ui view controller belongs to other ui parent") {
                        var uiParent: UIViewController!

                        beforeEach {
                            uiParent = UIViewController()
                            sceneViewController = UIViewController()

                            uiParent.addChild(sceneViewController)
                            uiParent.view.addSubview(sceneViewController.view)
                            sceneViewController.didMove(toParent: uiParent)

                            scene = WhimSingleScene(fullscreen: sceneViewController)
                        }

                        it("should add it") {
                            sut.push(scene: scene)

                            expect(sut.scenes).to(haveCount(2))
                            expect(sut.scenes[0]).to(beIdenticalTo(rootScene))
                            expect(sut.scenes[1]).to(beIdenticalTo(scene))
                        }
                    }

                    context("and its ui view controller doesn't belong to other ui parent") {
                        it("should add it") {
                            sut.push(scene: scene)

                            expect(sut.scenes).to(haveCount(2))
                            expect(sut.scenes[0]).to(beIdenticalTo(rootScene))
                            expect(sut.scenes[1]).to(beIdenticalTo(scene))
                        }
                    }

                    it("should become its parent and next responder") {
                        sut.push(scene: scene)

                        expect(scene.relationship.parent).to(beIdenticalTo(sut))
                        expect(scene.nextSceneResponder).to(beIdenticalTo(sut))
                    }

                    it("should tell responder to present it") {
                        let sutParent = FakeSceneNavigationStack(sut)

                        sut.push(scene: scene)

                        expect(sutParent.presentCall.capturedArgument?.scene).to(beIdenticalTo(scene))
                    }
                }

                context("which is itself") {
                    it("should do nothing") {
                        let scene = WhimSingleScene(fullscreen: UIViewController())
                        let sut = WhimSceneNavigationStack(scene)

                        sut.push(scene: sut)

                        expect(sut.scenes).to(haveCount(1))
                        expect(sut.scenes.first).to(beIdenticalTo(scene))
                    }
                }

                context("which is its parent") {
                    it("should do nothing") {
                        let scene = WhimSingleScene(fullscreen: UIViewController())
                        let sut = WhimSceneNavigationStack(scene)
                        let parent = WhimSceneNavigationStack(sut)

                        sut.push(scene: parent)

                        expect(sut.scenes).to(haveCount(1))
                        expect(sut.scenes.first).to(beIdenticalTo(scene))

                        expect(parent.scenes).to(haveCount(1))
                        expect(parent.scenes.first).to(beIdenticalTo(sut))
                    }
                }

                context("which is another navigation stack") {
                    var scene: WhimSingleScene!
                    var sut: WhimSceneNavigationStack!
                    var nav: WhimSceneNavigationStack!
                    var parent: FakeSceneNavigationStack!

                    beforeEach {
                        scene = WhimSingleScene(fullscreen: UIViewController())
                        sut = WhimSceneNavigationStack(scene)
                        nav = WhimSceneNavigationStack(WhimSingleScene(fullscreen: UIViewController()))
                        parent = FakeSceneNavigationStack(nav)
                    }

                    it("should add it") {
                        nav.push(scene: sut)

                        expect(nav.scenes).to(haveCount(2))
                        expect(nav.scenes[1]).to(beIdenticalTo(sut))
                    }

                    it("should tell responder to present its view controller") {
                        nav.push(scene: sut)

                        expect(parent.presentCall.capturedArgument?.scene).to(beIdenticalTo(sut))
                    }
                }

                context("while being a child of another navigation stack") {
                    var scene: WhimSingleScene!
                    var sut: WhimSceneNavigationStack!
                    var nav: WhimSceneNavigationStack!
                    var parent: FakeSceneNavigationStack!

                    beforeEach {
                        scene = WhimSingleScene(fullscreen: UIViewController())
                        sut = WhimSceneNavigationStack(WhimSingleScene(fullscreen: UIViewController()))
                    }

                    context("and on top of it") {
                        beforeEach {
                            nav = WhimSceneNavigationStack(
                                WhimSingleScene(fullscreen: UIViewController()),
                                WhimSingleScene(fullscreen: UIViewController()),
                                sut
                            )
                            parent = FakeSceneNavigationStack(nav)
                        }

                        it("should add it") {
                            sut.push(scene: scene)

                            expect(sut.scenes).to(haveCount(2))
                            expect(sut.scenes[1]).to(beIdenticalTo(scene))
                        }

                        it("its parent should also tell its responder to present new scene") {
                            sut.push(scene: scene)

                            expect(parent.presentCall.capturedArgument?.scene).to(beIdenticalTo(scene))
                        }
                    }

                    context("and in the middle of it") {
                        beforeEach {
                            nav = WhimSceneNavigationStack(
                                WhimSingleScene(fullscreen: UIViewController()),
                                sut,
                                WhimSingleScene(fullscreen: UIViewController())
                            )
                            parent = FakeSceneNavigationStack(nav)
                        }

                        it("should add it") {
                            sut.push(scene: scene)

                            expect(sut.scenes).to(haveCount(2))
                            expect(sut.scenes[1]).to(beIdenticalTo(scene))
                        }

                        it("its parent should not tell its responder to present new scene") {
                            sut.push(scene: scene)

                            expect(parent.presentCall.called).to(beFalse())
                        }
                    }
                }

                context("or multiple scenes") {
                    it("""
                       should add only those that do not belong to other or this stack,
                       are not this stack itself or its parent,
                       should become their parent and next responder,
                       and should tell its responder to present the last one
                       """) {
                        let sut = WhimSceneNavigationStack([])
                        let parent = FakeSceneNavigationStack(sut)
                        let sceneFromThisStack = WhimSingleScene(fullscreen: UIViewController())
                        sut.push(scene: sceneFromThisStack)

                        let scene = WhimSingleScene(fullscreen: UIViewController())
                        let stack = WhimSceneNavigationStack([])
                        let sceneFromOtherStack = WhimSingleScene(fullscreen: UIViewController())
                        let otherStack = WhimSceneNavigationStack([sceneFromOtherStack])

                        sut.push(scenes: [sceneFromOtherStack, stack, otherStack, sceneFromThisStack, parent, scene, sut])

                        expect(sut.scenes).to(haveCount(4))

                        expect(sut.scenes[0]).to(beIdenticalTo(sceneFromThisStack))
                        expect(sut.scenes[1]).to(beIdenticalTo(stack))
                        expect(sut.scenes[2]).to(beIdenticalTo(otherStack))
                        expect(sut.scenes[3]).to(beIdenticalTo(scene))

                        expect(sut.scenes.map(\.relationship.parent)).to(allPass { $0! === sut })
                        expect(sut.scenes.map(\.nextSceneResponder)).to(allPass { $0! === sut })

                        expect(parent.presentCall.capturedArgument?.scene).to(beIdenticalTo(scene))
                    }
                }
            }

            describe("when popping a scene") {
                context("and there are few scenes in the stack") {
                    var sut: WhimSceneNavigationStack!
                    var parent: FakeSceneNavigationStack!
                    var lastScene: WhimScene!
                    var prevScene: WhimScene!

                    beforeEach {
                        prevScene = WhimSingleScene(fullscreen: UIViewController())
                        lastScene = WhimSingleScene(fullscreen: UIViewController())
                        sut = WhimSceneNavigationStack(
                            WhimSingleScene(fullscreen: UIViewController()),
                            prevScene,
                            lastScene
                        )
                        parent = FakeSceneNavigationStack(sut)
                    }

                    it("should remove last scene from the stack and return it") {
                        let popped = sut.pop()

                        expect(popped).to(beIdenticalTo(lastScene))
                        expect(sut.scenes).to(haveCount(2))
                        expect(sut.scenes.last).to(beIdenticalTo(prevScene))
                    }

                    it("should tell its next responder to present previous scene") {
                        sut.pop()

                        expect(parent.presentCall.capturedArgument?.scene).to(beIdenticalTo(prevScene))
                    }
                }

                context("and there is only one scene in the stack") {
                    var sut: WhimSceneNavigationStack!
                    var parent: FakeSceneNavigationStack!
                    var scene: WhimScene!

                    beforeEach {
                        scene = WhimSingleScene(fullscreen: UIViewController())
                        sut = WhimSceneNavigationStack(scene)
                        parent = FakeSceneNavigationStack(sut)
                    }

                    it("should do nothing and return nil") {
                        let popped = sut.pop()

                        expect(popped).to(beNil())
                        expect(sut.scenes).to(haveCount(1))
                        expect(sut.scenes.last).to(beIdenticalTo(scene))
                    }

                    it("should not tell its next responder to present anything") {
                        sut.pop()

                        expect(parent.presentCall.called).to(beFalse())
                    }
                }
            }

            describe("when popping number of last scenes") {
                var parent: FakeSceneNavigationStack!
                var sut: WhimSceneNavigationStack!

                context("having empty stack") {
                    beforeEach {
                        sut = WhimSceneNavigationStack([])
                        parent = FakeSceneNavigationStack(sut)
                    }

                    context("with zero value") {
                        context("and swapping last scene") {
                            context("which already belongs to the other parent") {
                                var scene: WhimSingleScene!
                                var otherParent: WhimSceneNavigationStack!

                                beforeEach {
                                    scene = WhimSingleScene(fullscreen: UIViewController())
                                    otherParent = WhimSceneNavigationStack(scene)
                                }

                                it("should return empty array with false for the swapping result and do nothing") {
                                    let result = sut.pop(lastScenes: 0, andSwapLastWith: scene)

                                    expect(result.popped).to(beEmpty())
                                    expect(result.swapped).to(beFalse())
                                    expect(sut.scenes).to(beEmpty())
                                    expect(parent.presentCall.called).to(beFalse())
                                }
                            }

                            context("which is valid and can be added to the stack") {
                                var scene: WhimSingleScene!

                                beforeEach {
                                    scene = WhimSingleScene(fullscreen: UIViewController())
                                }

                                it("should return empty array with true for the swapping result and add it as a new scene") {
                                    let result = sut.pop(lastScenes: 0, andSwapLastWith: scene)

                                    expect(result.popped).to(beEmpty())
                                    expect(result.swapped).to(beTrue())
                                    expect(sut.scenes).to(haveCount(1))
                                    expect(sut.scenes.last).to(beIdenticalTo(scene))
                                }

                                it("should tell its responder to present it") {
                                    sut.pop(lastScenes: 0, andSwapLastWith: scene)

                                    expect(parent.presentCall.capturedArgument?.scene).to(beIdenticalTo(sut.scenes.last))
                                }
                            }
                        }
                    }
                }

                context("having non-empty stack") {
                    beforeEach {
                        sut = WhimSceneNavigationStack(
                            WhimSingleScene(fullscreen: UIViewController()),
                            WhimSingleScene(fullscreen: UIViewController()),
                            WhimSingleScene(fullscreen: UIViewController()),
                            WhimSingleScene(fullscreen: UIViewController())
                        )
                        parent = FakeSceneNavigationStack(sut)
                    }

                    context("with negative value") {
                        it("should return empty array and do nothing") {
                            expect(sut.pop(lastScenes: -2).popped).to(beEmpty())
                            expect(sut.scenes).to(haveCount(4))
                        }
                    }

                    context("with zero value") {
                        it("should return empty array and do nothing") {
                            expect(sut.pop(lastScenes: 0).popped).to(beEmpty())
                            expect(sut.scenes).to(haveCount(4))
                        }

                        context("and swapping last scene") {
                            context("which already belongs to the other parent") {
                                var scene: WhimSingleScene!
                                var otherParent: WhimSceneNavigationStack!

                                beforeEach {
                                    scene = WhimSingleScene(fullscreen: UIViewController())
                                    otherParent = WhimSceneNavigationStack(scene)
                                }

                                it("should return empty array with false for the swapping result and do nothing") {
                                    let result = sut.pop(lastScenes: 0, andSwapLastWith: scene)

                                    expect(result.popped).to(beEmpty())
                                    expect(result.swapped).to(beFalse())
                                    expect(sut.scenes).to(haveCount(4))
                                    expect(sut.scenes.last).toNot(beIdenticalTo(scene))
                                    expect(parent.presentCall.called).to(beFalse())
                                }
                            }

                            context("which is valid and can be added to the stack") {
                                var scene: WhimSingleScene!

                                beforeEach {
                                    scene = WhimSingleScene(fullscreen: UIViewController())
                                }

                                it("should return empty array with true for the swapping result and add it as a new scene") {
                                    let result = sut.pop(lastScenes: 0, andSwapLastWith: scene)

                                    expect(result.popped).to(beEmpty())
                                    expect(result.swapped).to(beTrue())
                                    expect(sut.scenes).to(haveCount(4))
                                    expect(sut.scenes.last).to(beIdenticalTo(scene))
                                }

                                it("should tell its responder to present it") {
                                    sut.pop(lastScenes: 0, andSwapLastWith: scene)

                                    expect(parent.presentCall.capturedArgument?.scene).to(beIdenticalTo(sut.scenes.last))
                                }
                            }
                        }
                    }

                    context("with value not less than stack size") {
                        it("should return empty array and do nothing") {
                            let result1 = sut.pop(lastScenes: 4, andSwapLastWith: WhimSingleScene(fullscreen: .init()))
                            expect(result1.popped).to(beEmpty())
                            expect(result1.swapped).to(beFalse())
                            expect(sut.pop(lastScenes: 5).popped).to(beEmpty())
                            expect(sut.scenes).to(haveCount(4))
                            expect(parent.presentCall.called).to(beFalse())
                        }
                    }

                    context("with value less than stack size") {
                        it("should return exact number of scenes from the stack and tell its responder to present the topmost scene") {
                            let lastTwoScenes = Array(sut.scenes.suffix(2))
                            let result = sut.pop(lastScenes: 2).popped

                            expect(result).to(haveCount(2))
                            expect(result[0]).to(beIdenticalTo(lastTwoScenes[0]))
                            expect(result[1]).to(beIdenticalTo(lastTwoScenes[1]))

                            expect(sut.scenes).to(haveCount(2))
                            expect(parent.presentCall.capturedArgument?.scene).to(beIdenticalTo(sut.scenes.last))
                        }

                        context("and swapping last scene") {
                            context("which already belongs to the other parent") {
                                var scene: WhimSingleScene!
                                var otherParent: WhimSceneNavigationStack!

                                beforeEach {
                                    scene = WhimSingleScene(fullscreen: UIViewController())
                                    otherParent = WhimSceneNavigationStack(scene)
                                }

                                it("should return exact number of scenes from the stack with false for swapping result") {
                                    let lastTwoScenes = Array(sut.scenes.suffix(2))
                                    let result = sut.pop(lastScenes: 2, andSwapLastWith: scene)

                                    expect(result.popped).to(haveCount(2))
                                    expect(result.swapped).to(beFalse())
                                    expect(result.popped[0]).to(beIdenticalTo(lastTwoScenes[0]))
                                    expect(result.popped[1]).to(beIdenticalTo(lastTwoScenes[1]))

                                    expect(sut.scenes).to(haveCount(2))
                                    expect(sut.scenes.last).toNot(beIdenticalTo(scene))
                                }

                                it("should tell its responder to present the topmost scene without swapping it") {
                                    sut.pop(lastScenes: 2, andSwapLastWith: scene)

                                    expect(parent.presentCall.capturedArgument?.scene).to(beIdenticalTo(sut.scenes.last))
                                }
                            }

                            context("which is valid and can be added to the stack") {
                                var scene: WhimSingleScene!

                                beforeEach {
                                    scene = WhimSingleScene(fullscreen: UIViewController())
                                }

                                it("should return exact number of scenes from the stack with true for swapping result") {
                                    let lastTwoScenes = Array(sut.scenes.suffix(2))
                                    let result = sut.pop(lastScenes: 2, andSwapLastWith: scene)

                                    expect(result.popped).to(haveCount(2))
                                    expect(result.swapped).to(beTrue())
                                    expect(result.popped[0]).to(beIdenticalTo(lastTwoScenes[0]))
                                    expect(result.popped[1]).to(beIdenticalTo(lastTwoScenes[1]))

                                    expect(sut.scenes).to(haveCount(2))
                                    expect(sut.scenes.last).to(beIdenticalTo(scene))
                                }

                                it("should tell its responder to present the topmost scene which is swapped with the new one") {
                                    sut.pop(lastScenes: 2, andSwapLastWith: scene)

                                    expect(parent.presentCall.capturedArgument?.scene).to(beIdenticalTo(sut.scenes.last))
                                }
                            }
                        }
                    }
                }
            }

            describe("when popping to a scene") {
                var parent: FakeSceneNavigationStack!
                var sut: WhimSceneNavigationStack!
                var scene: WhimScene!

                context("which doesn't belong to the stack") {
                    beforeEach {
                        scene = WhimSingleScene(fullscreen: UIViewController())
                        sut = WhimSceneNavigationStack(
                            WhimSingleScene(fullscreen: UIViewController()),
                            WhimSingleScene(fullscreen: UIViewController()),
                            WhimSingleScene(fullscreen: UIViewController())
                        )
                        parent = FakeSceneNavigationStack(sut)
                    }

                    it("should do nothing and return nil") {
                        let popped = sut.pop(to: scene)

                        expect(popped).to(beNil())
                        expect(sut.scenes).to(haveCount(3))
                        expect(parent.presentCall.called).to(beFalse())
                    }
                }

                context("which belongs to the stack") {
                    var popped1: WhimScene!
                    var popped2: WhimScene!

                    beforeEach {
                        popped1 = WhimSingleScene(fullscreen: UIViewController())
                        popped2 = WhimSingleScene(fullscreen: UIViewController())
                        scene = WhimSingleScene(fullscreen: UIViewController())
                        sut = WhimSceneNavigationStack(
                            WhimSingleScene(fullscreen: UIViewController()),
                            WhimSingleScene(fullscreen: UIViewController()),
                            scene,
                            popped1,
                            popped2
                        )
                        parent = FakeSceneNavigationStack(sut)
                    }

                    it("should remove all scenes after given scene and return them") {
                        let popped = sut.pop(to: scene)

                        expect(sut.scenes).to(haveCount(3))
                        expect(sut.scenes.last).to(beIdenticalTo(scene))

                        expect(popped).to(haveCount(2))
                        expect(popped?[0]).to(beIdenticalTo(popped1))
                        expect(popped?[1]).to(beIdenticalTo(popped2))
                    }

                    it("tell its next responder to present given scene") {
                        sut.pop(to: scene)

                        expect(parent.presentCall.capturedArgument?.scene).to(beIdenticalTo(scene))
                    }
                }

                context("being the last one in the stack") {
                    beforeEach {
                        scene = WhimSingleScene(fullscreen: UIViewController())
                        sut = WhimSceneNavigationStack(
                            WhimSingleScene(fullscreen: UIViewController()),
                            WhimSingleScene(fullscreen: UIViewController()),
                            scene
                        )
                        parent = FakeSceneNavigationStack(sut)
                    }

                    it("should do nothing and return empty array") {
                        let popped = sut.pop(to: scene)

                        expect(popped).to(beEmpty())
                        expect(sut.scenes).to(haveCount(3))
                        expect(sut.scenes.last).to(beIdenticalTo(scene))
                        expect(parent.presentCall.called).to(beFalse())
                    }
                }
            }

            describe("when popping to root") {
                var parent: FakeSceneNavigationStack!
                var sut: WhimSceneNavigationStack!
                var root: WhimScene!

                beforeEach {
                    root = WhimSingleScene(fullscreen: UIViewController())
                    sut = WhimSceneNavigationStack(
                        root,
                        WhimSingleScene(fullscreen: UIViewController()),
                        WhimSingleScene(fullscreen: UIViewController()),
                        WhimSingleScene(fullscreen: UIViewController())
                    )
                    parent = FakeSceneNavigationStack(sut)
                }

                it("should remove all scenes after root scene") {
                    sut.popToRoot()

                    expect(sut.scenes).to(haveCount(1))
                    expect(sut.scenes.first).to(beIdenticalTo(root))
                }

                it("tell its next responder to present root scene") {
                    sut.popToRoot()

                    expect(parent.presentCall.capturedArgument?.scene).to(beIdenticalTo(root))
                }

                context("multiple times") {
                    it("should do it only once") {
                        sut.popToRoot()
                        sut.popToRoot()
                        sut.popToRoot()

                        expect(sut.scenes).to(haveCount(1))
                        expect(sut.scenes.first).to(beIdenticalTo(root))
                        expect(parent.presentCall.callsCount).to(equal(1))
                    }
                }
            }

            describe("when swapping last scene") {
                var sut: WhimSceneNavigationStack!
                var parent: FakeSceneNavigationStack!

                context("having an empty stack") {
                    beforeEach {
                        sut = WhimSceneNavigationStack([])
                        parent = FakeSceneNavigationStack(sut)
                    }

                    context("with the one that already belongs to the other parent") {
                        var scene: WhimSingleScene!
                        var otherParent: WhimSceneNavigationStack!

                        beforeEach {
                            scene = WhimSingleScene(fullscreen: UIViewController())
                            otherParent = WhimSceneNavigationStack(scene)
                        }

                        it("should return false and do nothing") {
                            expect(sut.swapLast(with: scene)).to(beFalse())
                            expect(sut.scenes).to(beEmpty())
                        }
                    }

                    context("which is valid and can be added to the stack") {
                        var scene: WhimSingleScene!

                        beforeEach {
                            scene = WhimSingleScene(fullscreen: UIViewController())
                        }

                        it("should return true and add it as a new scene") {
                            expect(sut.swapLast(with: scene)).to(beTrue())
                            expect(sut.scenes).to(haveCount(1))
                            expect(sut.scenes.last).to(beIdenticalTo(scene))
                        }
                    }
                }

                context("with other scenes being in the stack") {
                    beforeEach {
                        sut = WhimSceneNavigationStack(
                            WhimSingleScene(fullscreen: UIViewController()),
                            WhimSingleScene(fullscreen: UIViewController()),
                            WhimSingleScene(fullscreen: UIViewController()),
                            WhimSingleScene(fullscreen: UIViewController())
                        )
                        parent = FakeSceneNavigationStack(sut)
                    }

                    context("with the one that already belongs to the other parent") {
                        var scene: WhimSingleScene!
                        var otherParent: WhimSceneNavigationStack!

                        beforeEach {
                            scene = WhimSingleScene(fullscreen: UIViewController())
                            otherParent = WhimSceneNavigationStack(scene)
                        }

                        it("should return false and do nothing") {
                            expect(sut.swapLast(with: scene)).to(beFalse())
                            expect(sut.scenes).to(haveCount(4))
                            expect(sut.scenes.last).toNot(beIdenticalTo(scene))
                        }

                        it("should not tell its responder to present the topmost scene again") {
                            sut.swapLast(with: scene)

                            expect(parent.presentCall.called).to(beFalse())
                        }
                    }

                    context("which is valid and can be added to the stack") {
                        var scene: WhimSingleScene!

                        beforeEach {
                            scene = WhimSingleScene(fullscreen: UIViewController())
                        }

                        it("should return true and add it as a new scene") {
                            expect(sut.swapLast(with: scene)).to(beTrue())
                            expect(sut.scenes).to(haveCount(4))
                            expect(sut.scenes.last).to(beIdenticalTo(scene))
                        }

                        it("should tell its responder to present the topmost scene which is swapped with the new one") {
                            sut.swapLast(with: scene)

                            expect(parent.presentCall.capturedArgument?.scene).to(beIdenticalTo(sut.scenes.last))
                        }
                    }
                }
            }
        }
    }
}
