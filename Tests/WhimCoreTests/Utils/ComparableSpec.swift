import Quick
import Nimble

@testable import WhimCore

class ComparableExtensionsSpec: QuickSpec {
    override func spec() {
        describe("Comparabe") {
            describe("inRange") {
                context("when min is greater than max") {
                    it("should return current value") {
                        expect(42.inRange(min: 40, max: 0)).to(equal(42))
                        expect(42.inRange(min: -1, max: -40)).to(equal(42))
                    }
                }

                context("when current value is within min and max values") {
                    it("should return current value") {
                        expect(40.inRange(min: 0, max: 42)).to(equal(40))
                        expect((-40).inRange(min: -42, max: -1)).to(equal(-40))
                    }
                }

                context("when current value is less than min value") {
                    it("should return min value") {
                        expect(5.inRange(min: 10, max: 40)).to(equal(10))
                        expect((-42).inRange(min: -40, max: -1)).to(equal(-40))
                    }
                }

                context("when current value is greater than max value") {
                    it("should return max value") {
                        expect(42.inRange(min: 0, max: 40)).to(equal(40))
                        expect(0.inRange(min: -42, max: -1)).to(equal(-1))
                    }
                }
            }
        }
    }
}
