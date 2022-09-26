import XCTest
import RxSwift
import RxCocoa
@testable import WhimCore

final class ObservablePropertyTests: XCTestCase {
    func test_initWithBehaviorRelay_value() {
        let relay = BehaviorRelay<Int>(value: 0)
        let property = ObservableProperty<Int>(relay)

        XCTAssertEqual(property.value, 0)

        relay.accept(1)
        XCTAssertEqual(property.value, 1)

        relay.accept(2)
        XCTAssertEqual(property.value, 2)

    }

    func test_initWithBehaviorRelay_asObservable() {
        let relay = BehaviorRelay<Int>(value: 0)
        var property: ObservableProperty<Int>! = .init(relay)

        var events = [Event<Int>]()

        _ = property.asObservable().subscribe { event in
            events.append(event)
        }

        XCTAssertEqual(events, [.next(0)], "should observe initial value")

        relay.accept(1)
        XCTAssertEqual(events, [.next(0), .next(1)])

        relay.accept(2)
        XCTAssertEqual(events, [.next(0), .next(1), .next(2)])

        property = nil
        XCTAssertEqual(events, [.next(0), .next(1), .next(2)], "`.completed` should NOT be observed when `property` is deallocated")

        relay.accept(3)
        XCTAssertEqual(events, [.next(0), .next(1), .next(2), .next(3)], "`property`'s observable should still be alive even when `property` is deallocated.")
    }

    func test_initWithValueAndObservable_value() {
        let relay = PublishRelay<Int>()
        let property = ObservableProperty<Int>(initial: 0, then: relay.asObservable())

        XCTAssertEqual(property.value, 0)

        relay.accept(1)
        XCTAssertEqual(property.value, 1)

        relay.accept(2)
        XCTAssertEqual(property.value, 2)

    }

    func test_initWithValueAndObservable_asObservable() {
        let relay = PublishRelay<Int>()
        var property: ObservableProperty<Int>! = .init(initial: 0, then: relay.asObservable())

        var events = [Event<Int>]()

        _ = property.asObservable().subscribe { event in
            events.append(event)
        }

        XCTAssertEqual(events, [.next(0)], "should observe initial value")

        relay.accept(1)
        XCTAssertEqual(events, [.next(0), .next(1)])

        relay.accept(2)
        XCTAssertEqual(events, [.next(0), .next(1), .next(2)])

        property = nil
        XCTAssertEqual(events, [.next(0), .next(1), .next(2)], "`.completed` should NOT be observed when `property` is deallocated")

        relay.accept(3)
        XCTAssertEqual(events, [.next(0), .next(1), .next(2), .next(3)], "`property`'s observable should still be alive even when `property` is deallocated.")
    }
}
