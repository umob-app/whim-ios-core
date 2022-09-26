import Quick
import Nimble

@testable import WhimCore

final class HomeSceneViewControllerSpec: QuickSpec {
    override func spec() {
        describe("HomeSceneViewControllerValue") {
            describe("when mapping") {
                context("each case separately") {
                    it("should return transformed value for the same option") {
                        let sut = HomeSceneViewControllerValue.multipart(top: 42, bottom: 24).map(
                            fullscreen: { "\($0)" },
                            multipart: { ("top: \($0)", "bottom: \($1)") }
                        )

                        expect(sut).to(equal(.multipart(top: "top: 42", bottom: "bottom: 24")))
                    }
                }

                context("with general rule") {
                    it("should return transformed value for the same option") {
                        let sut = HomeSceneViewControllerValue.multipart(top: 42, bottom: 24).map {
                            "\($0)"
                        }

                        expect(sut).to(equal(.multipart(top: "42", bottom: "24")))
                    }
                }
            }

            describe("when updating by key path") {
                class TestObject { var value: Int = 0 }

                context("with a different view controller value") {
                    context("of a different option") {
                        it("should not do anything") {
                            let obj = TestObject()
                            HomeSceneViewControllerValue.fullscreen(obj).update(
                                keyPath: \.value,
                                with: .multipart(top: 42, bottom: 24)
                            )

                            expect(obj.value).to(equal(0))
                        }
                    }

                    context("of the same option") {
                        it("it should update its corresponding values") {
                            let top = TestObject()
                            let bottom = TestObject()

                            HomeSceneViewControllerValue.multipart(top: top, bottom: bottom).update(
                                keyPath: \.value,
                                with: .multipart(top: 42, bottom: 24)
                            )

                            expect(top.value).to(equal(42))
                            expect(bottom.value).to(equal(24))
                        }
                    }
                }

                context("each case separately") {
                    it("should return transformed value for the same option") {
                        let top = TestObject()
                        let bottom = TestObject()

                        HomeSceneViewControllerValue.multipart(top: top, bottom: bottom).update(
                            keyPath: \.value,
                            fullscreen: { _ in 1 },
                            multipart: { _, _ in (42, 24) }
                        )

                        expect(top.value).to(equal(42))
                        expect(bottom.value).to(equal(24))
                    }
                }

                context("with a single value") {
                    it("should return transformed value for the same option") {
                        let top = TestObject()
                        let bottom = TestObject()

                        HomeSceneViewControllerValue.multipart(top: top, bottom: bottom).update(
                            keyPath: \.value,
                            with: 42
                        )

                        expect(top.value).to(equal(42))
                        expect(bottom.value).to(equal(42))
                    }
                }
            }
        }
    }
}
