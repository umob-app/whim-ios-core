import XCTest
import Nimble
import RxSwift
import RxCocoa
import RxTest
import RxBlocking

@testable import WhimCore

// MARK: - System

class FeedbackLoopSystemTests: XCTestCase {
    func test_whenCreated_systemShouldImmediatelyStartByItself() {
        let scheduler = TestScheduler(initialClock: 0)
        let sut = FeedbackSystem(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                Feedback<String, String> { scheduler, input in
                    input.take(1).map { _ in "event" }
                }
            ]
        )

        XCTAssertEqual(sut.state.value, "initial")
        scheduler.advanceTo(10)
        XCTAssertEqual(sut.state.value, "initial_event")
    }

    func test_stateUpdates_shouldArriveOnCorrectScheduler() {
        let exp = expectation(description: "test_stateUpdates_shouldArriveOnCorrectScheduler")
        // 2 for state updates + 1 for comlpetion
        exp.expectedFulfillmentCount = 3
        let disposeBag = DisposeBag()
        let sut = FeedbackSystem(
            initial: "initial",
            scheduler: SerialDispatchQueueScheduler(qos: .userInitiated),
            reduce: { state, event in
                state = state + "_" + event
            },
            feedbacks: [.just(effects: Observable.just("a").timeout(.milliseconds(30), scheduler: MainScheduler.instance))]
        )
        // listening to updates straight from the system
        var results = [String]()
        sut.asObservable()
            .take(2)
            .subscribe(onNext: {
                results.append($0)

                XCTAssertTrue(DispatchQueue.isUserInitiated)
                exp.fulfill()
            }, onCompleted: {
                XCTAssertTrue(DispatchQueue.isUserInitiated)
                exp.fulfill()
            })
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 5.0) { e in
            XCTAssertEqual(results, ["initial", "initial_a"])
        }
    }

    func test_initialValue_shouldBeDelivered() {
        let disposeBag = DisposeBag()
        let scheduler = TestScheduler(initialClock: 0)
        let sut = FeedbackSystem<String, String>(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in },
            feedbacks: []
        )

        var result = ""
        sut.asObservable().subscribe(onNext: { result += $0 }).disposed(by: disposeBag)
        scheduler.advanceTo(10)

        XCTAssertEqual(result, "initial")
    }

    func test_systemEvents_shouldBeProcessedInCorrectOrder() {
        let disposeBag = DisposeBag()
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(String.self)
        let sut = FeedbackSystem(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                Feedback { input -> Observable<String> in
                    if input.state == "initial" {
                        return Observable.just("a").delay(.milliseconds(10), scheduler: scheduler)
                    } else if input.state == "initial_a" {
                        return .just("b")
                    } else if input.state == "initial_a_b" {
                        return .just("c")
                    }
                    return .never()
                }
            ]
        )
        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.start()

        XCTAssertRecordedElements(observer.events, [
            "initial",
            "initial_a",
            "initial_a_b",
            "initial_a_b_c"
        ])
    }

    func test_twoImmediateFeedbacks_shouldDeliverEventsInCorrectOrder() {
        let disposeBag = DisposeBag()
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(String.self)
        let sut = FeedbackSystem(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                Feedback { input -> Observable<String> in
                    !input.state.hasSuffix("a") ? .just("a") : .never()
                },
                Feedback { input -> Observable<String> in
                    !input.state.hasSuffix("b") ? .just("b") : .never()
                }
            ]
        )
        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)

        XCTAssertRecordedElements(Array(observer.events.prefix(5)), [
            "initial",
            "initial_a",
            "initial_a_b",
            "initial_a_b_a",
            "initial_a_b_a_b"
        ])
    }

    func test_immediateParallelFeedbacks_shouldDeliverEventsInCorrectOrder() {
        let disposeBag = DisposeBag()
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(String.self)
        let feedback = Feedback<String, String> { input in
            if input.state == "initial" {
                return .just("a")
            } else if input.state == "initial_a" {
                return .just("b")
            } else if input.state == "initial_a_b" {
                return .just("c")
            }
            return .never()
        }
        let sut = FeedbackSystem(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [feedback, feedback, feedback]
        )
        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.start()

        XCTAssertRecordedElements(observer.events, [
            "initial",
            "initial_a",
            "initial_a_b",
            "initial_a_b_c"
        ])
    }

    func test_shouldNotMissExternalEvent_withSyncScheduler_duringSystemSetup() {
        let events = PublishSubject<String>()
        let sut = FeedbackSystem(
            initial: "initial",
            scheduler: MainScheduler.instance,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                .just(effects: events.asObservable())
            ]
        )
        // we treat it as 'during' system setup, as it's usually asynchronous,
        // however I've discovered that given synchronous scheduler it's able to receive external event immediately
        events.onNext("a")

        let result = try! sut.asObservable()
            .take(2)
            .toBlocking(timeout: 5.0)
            .toArray()

        XCTAssertEqual(result, ["initial", "initial_a"])
    }

    func test_shouldMissExternalEvent_withAsyncScheduler_duringSystemSetup() {
        // this assertion should fail after FeedbackLoop is made synchronous (i.e. https://github.com/ReactiveCocoa/Loop)
        let events = PublishSubject<String>()
        let sut = FeedbackSystem(
            initial: "initial",
            scheduler: MainScheduler.asyncInstance,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                .just(effects: events.asObservable())
            ]
        )
        // we treat it as 'during' system setup, as it's usually asynchronous
        events.onNext("a")

        let result = try! sut.asObservable()
            // 50 milliseconds should be enough to prove that external event didn't pass through,
            // though it might need some adjustment for slower CI machine such as travis or jenkins
            .take(for: .milliseconds(50), scheduler: MainScheduler.instance)
            .toBlocking(timeout: 5.0)
            .toArray()

        XCTAssertEqual(result, ["initial"])
    }

    func test_shouldNotMissExternalEvent_withAsyncScheduler_afterSystemSetup() {
        let events = PublishSubject<String>()
        let sut = FeedbackSystem(
            initial: "initial",
            scheduler: MainScheduler.asyncInstance,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                .just(effects: events.asObservable())
            ]
        )
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(10)) {
            // we treat it as 'after' system setup, as it's usually asynchronous
            events.onNext("a")
        }

        let result = try! sut.asObservable()
            .take(2)
            .toBlocking(timeout: 5.0)
            .toArray()

        XCTAssertEqual(result, ["initial", "initial_a"])
    }

    func test_whenStartedAsynchronously_shouldNotMissDeliveryToReducer() {
        let disposeBag = DisposeBag()
        let creationScheduler = SerialDispatchQueueScheduler(qos: .default)
        let systemScheduler = SerialDispatchQueueScheduler(qos: .userInitiated)

        let observedState: Atomic<[String]> = Atomic([])
        let exp = expectation(description: "test_whenStartedAsynchronously_shouldNotMissDeliveryToReducer")
        exp.expectedFulfillmentCount = 2
        // need to retain reference to actie system to keep it alive
        var sut: FeedbackSystem<String, String>!

        creationScheduler.schedule("initial") { initial in
            sut = FeedbackSystem<String, String>(
                initial: initial,
                scheduler: systemScheduler,
                reduce: { state, event in
                    state += "_" + event
                },
                feedbacks: [
                    Feedback { scheduler, input in
                        input.take(1).map { _ in "event" }.observe(on: scheduler)
                        // `onCompleted` is called before subscriber gets next state, and expectation is fulfilled prematurely.
                        // Thus fulfilling expectation right in-place, where new state is appended in subscription block.
                        //
                        // .do(onCompleted: {
                        //     exp.fulfill()
                        // })
                    }
                ]
            )
            return sut.asObservable().subscribe(onNext: { state in
                observedState.mutate {
                    $0.append(state)
                }
                exp.fulfill()
            })
        }
        .disposed(by: disposeBag)

        waitForExpectations(timeout: 5.0) { error in
            XCTAssertEqual(observedState.value, ["initial", "initial_event"])
        }
    }

    func test_externalEventsAreNotCancelled_whenSourceCompletes() {
        enum Event {
            case increment(by: Int)
            case timeConsumingWork
        }

        let semaphore = DispatchSemaphore(value: 0)
        let increments = PublishSubject<Int>()
        let workTrigger = PublishSubject<Void>()

        let sut = FeedbackSystem<Int, Event>(
            initial: 0,
            scheduler: MainScheduler.instance,
            reduce: { state, event in
                switch event {
                case let .increment(steps):
                    state += steps
                case .timeConsumingWork:
                    semaphore.wait()
                }
            },
            feedbacks: [
                .just(effects: increments.map(Event.increment)),
                .just(effects: workTrigger.map { Event.timeConsumingWork })
            ]
        )

        // assert current value
        try! XCTAssertEqual(sut.asObservable().take(1).toBlocking(timeout: 5.0).toArray(), [0])

        increments.onNext(1)
        increments.onNext(2)
        increments.onNext(3)

        // assert current value (last 0 from previous assertion) + 3 increments
        try! XCTAssertEqual(sut.asObservable().take(4).toBlocking(timeout: 5.0).toArray(), [0, 1, 3, 6])

        workTrigger.onNext(())

        increments.onNext(1)
        increments.onNext(2)
        increments.onNext(3)
        increments.onCompleted()

        // Allow the reducer running in background to proceed.
        semaphore.signal()

        // assert current value (last 6 from previous assertion) + 3 more increments
        try! XCTAssertEqual(sut.asObservable().take(5).toBlocking(timeout: 5.0).toArray(), [6, 6, 7, 9, 12])
    }

    func test_shouldNotDeadlock_whenFeedbackEffectStartsSystemSynchronously() {
        let disposeBag = DisposeBag()
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(Int.self)
        let events = PublishSubject<Int>()
        var _sut: FeedbackSystem<Int, Int>!
        let sut = FeedbackSystem<Int, Int>(
            initial: 0,
            scheduler: scheduler,
            reduce: { state, event in
                state += event
            },
            feedbacks: [
                .just(effects: events),
                .skippingRepeated(
                    state: { $0 == 1 },
                    effects: {
                        $0 == 1
                            ? _sut.asObservable().map { _ in 1000 }.take(1)
                            : .empty()
                    }
                )
            ]
        )
        _sut = sut

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)
        XCTAssertRecordedElements(observer.events, [0])

        events.onNext(1)
        scheduler.advanceTo(20)
        XCTAssertRecordedElements(observer.events, [0, 1, 1001])
    }

    func test_feedbackStatesStreamReplaysLatestValue_whenSkippingFirstOne() {
        // duplicating this test:
        // https://github.com/ReactiveCocoa/Loop/blob/ccc614489688db1829091b3d2481c2345fdab320/LoopTests/FeedbackLoopSystemTests.swift#L308
        // however due to async nature of the system, we don't immediately get the very last state when concatenating with the second stream,
        // so we have to skip first update to achieve same result.
        let disposeBag = DisposeBag()
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(Int.self)
        let sut = FeedbackSystem<Int, Int>(
            initial: 0,
            scheduler: scheduler,
            reduce: { state, event in
                state += event
            },
            feedbacks: [
                Feedback { scheduler, input in
                    let state = input.filter(\.event.isNil).map(\.state)
                    return Observable.concat(
                        state.take(1).map { _ in 2 },
                        state.skip(1).take(3).map { $0 + 1000 }
                    )
                    .observe(on: scheduler)
                }
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.start()

        // state + event         = state
        // 0                     = 0      # initial
        // 0     + 2             = 2      # from `map(value: 2)`
        // 2     + (2    + 1000) = 1004   # from the 1st value yielded by `concat(...)`
        // 1004  + (1004 + 1000) = 3008   # from the 2nd value yielded by `concat(...)`
        // 3008  + (3008 + 1000) = 7016   # from the 3rd value yielded by `concat(...)`

        XCTAssertRecordedElements(observer.events, [0, 2, 1004, 3008, 7016])
    }

    func test_feedbackStatesStreamReplaysPreviousValue_whenNotSkippingAny() {
        // duplicating this test:
        // https://github.com/ReactiveCocoa/Loop/blob/ccc614489688db1829091b3d2481c2345fdab320/LoopTests/FeedbackLoopSystemTests.swift#L308
        // however due to async nature of the system, we don't immediately get the very last state when concatenating with the second stream,
        // instead we get previous state, as shown in this test (unless we skip first update after concat as we do in prev test ^)
        let disposeBag = DisposeBag()
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(Int.self)
        let sut = FeedbackSystem<Int, Int>(
            initial: 0,
            scheduler: scheduler,
            reduce: { state, event in
                state += event
            },
            feedbacks: [
                Feedback { scheduler, input in
                    let state = input.filter(\.event.isNil).map(\.state)
                    return Observable.concat(
                        state.take(1).map { _ in 2 },
                        state.take(3).map { $0 + 1000 }
                    )
                    .observe(on: scheduler)
                }
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.start()

        // state + event         = state
        // 0                     = 0      # initial
        // 0     + 2             = 2      # from `map(value: 2)`
        // 2     + (0    + 1000) = 1002   # from the 1st value yielded by `concat(...)`
        // 1002  + (2    + 1000) = 2004   # from the 2nd value yielded by `concat(...)`
        // 2004  + (1002 + 1000) = 4006   # from the 3rd value yielded by `concat(...)`

        XCTAssertRecordedElements(observer.events, [0, 2, 1002, 2004, 4006])
    }

    func test_shouldProcessExternalEvents_whenStartingSystemSubscription() {
        let disposeBag = DisposeBag()
        let scheduler = TestScheduler(initialClock: 0)
        let events = PublishSubject<Int>()
        let sut = FeedbackSystem<Int, Int>(
            initial: 0,
            scheduler: scheduler,
            reduce: { state, event in
                state += event
            },
            feedbacks: [.just(effects: events)]
        )

        var latestCount: Int?
        var hasSentEvent = false

        sut.asObservable()
            .do(onNext: { _ in
                if !hasSentEvent {
                    hasSentEvent = true
                    events.onNext(1000)
                }
            })
            .subscribe(onNext: { state in
                latestCount = state
            })
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(latestCount, 1000)
    }

    func test_externalEvents_areDeliveredInCorrectOrder() {
        let disposeBag = DisposeBag()
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(Int.self)
        let events = PublishSubject<Int>()

        var recordedEvents: [Int] = []
        let sut = FeedbackSystem<Int, Int>(
            initial: 0,
            scheduler: scheduler,
            reduce: { state, event in
                state += event
                recordedEvents.append(event)
            },
            feedbacks: [.just(effects: events)]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)

        events.onNext(1)
        events.onNext(2)
        events.onNext(3)

        scheduler.start()

        XCTAssertRecordedElements(observer.events, [0, 1, 3, 6])
        XCTAssertEqual(recordedEvents, [1, 2, 3])
    }

    func test_stateAndEventUpdates_shouldBeDeliveredInCorrectOrder() {
        let disposeBag = DisposeBag()
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(Int.self)
        let events = PublishSubject<Int>()

        var recordedInputs: [(Int, Int?)] = []
        let sut = FeedbackSystem<Int, Int>(
            initial: 0,
            scheduler: scheduler,
            reduce: { state, event in
                state += event
            },
            feedbacks: [
                .just(effects: events),
                Feedback { scheduler, input in
                    input.do(onNext: {
                        recordedInputs.append($0)
                    }).flatMapLatest { _ in
                        Observable.empty().observe(on: scheduler)
                    }
                }
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)

        events.onNext(1)
        events.onNext(2)
        events.onNext(3)

        scheduler.start()

        XCTAssertRecordedElements(observer.events, [0, 1, 3, 6])
        XCTAssertEqual(recordedInputs.map(Tuple.init), [
            Tuple(0, nil), // initial state
            Tuple(1, nil), // first state is changed by reducer, so we get new state without event yet
            Tuple(1, 1),   // next we deliver event with the updated state
            Tuple(3, nil), // and so on - first state update, then event that caused that update with the new state
            Tuple(3, 2),
            Tuple(6, nil),
            Tuple(6, 3)
        ])
    }

    // TODO: CwlPreconditionTesting - Support Apple Silicon: https://github.com/mattgallagher/CwlPreconditionTesting/issues/21
    #if arch(x86_64)
    func test_sendingEvent_shouldBeReentrantSafe() {
        let disposeBag = DisposeBag()
        let scheduler = TestScheduler(initialClock: 0)
        let events = PublishSubject<Int>()
        var whenEqualToOne: (() -> Void)?

        let sut = FeedbackSystem<Int, Int>(
            initial: 0,
            scheduler: scheduler,
            reduce: { state, event in
                state += event
            },
            feedbacks: [
                .just(effects: events),
                .whenBecomesTrue(
                    state: { $0 == 1 },
                    effects: { _ in Observable.empty().do(onCompleted: { whenEqualToOne?() }) }
                )
            ]
        )

        whenEqualToOne = { [weak events] in events?.onNext(2) }

        scheduler.advanceTo(10)

        var states: [Int] = []
        sut.asObservable().subscribe(onNext: { state in
            if state == 3 {
                events.onNext(3)
            }
            states.append(state)
        }).disposed(by: disposeBag)

        // this thing can only be correctly checked by CwlPreconditionTesting which is available out of box using Nimble matcher
        expect { events.onNext(1) }.toNot(throwAssertion())

        scheduler.start()

        XCTAssertEqual(states, [0, 1, 3, 6])
    }
    #endif

    func test_systemShouldDeinit_whenNoOneRetainsIt() {
        weak var sut: FeedbackSystem<Int, Int>?

        autoreleasepool {
            let deinitSut = FeedbackSystem<Int, Int>(
                initial: 0,
                scheduler: MainScheduler.asyncInstance,
                reduce: { state, event in
                    state += event
                },
                feedbacks: []
            )
            sut = deinitSut
        }

        XCTAssertNil(sut)
    }

    func test_systemShouldDeinit_whenNoOneRetainsIt_evenIfExternalEventsAreStillProduced() {
        weak var sut: FeedbackSystem<Int, Int>?
        let events = PublishSubject<Int>()
        let scheduler = TestScheduler(initialClock: 0)

        autoreleasepool {
            let deinitSut = FeedbackSystem<Int, Int>(
                initial: 0,
                scheduler: scheduler,
                reduce: { state, event in
                    state += event
                },
                feedbacks: [.just(effects: events)]
            )
            sut = deinitSut

            scheduler.advanceTo(10)
            events.onNext(1)
            scheduler.advanceTo(20)
        }

        events.onNext(2)
        scheduler.start()

        XCTAssertNil(sut)
    }

    func test_systemShouldDeinit_whenNoOneRetainsIt_evenIfLongRunningFeedbackIsInProgress() {
        weak var sut: FeedbackSystem<Int, Int>?
        let disposeBag = DisposeBag()
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(Int.self)

        var isDisposed = false
        autoreleasepool {
            let deinitSut = FeedbackSystem<Int, Int>(
                initial: 0,
                scheduler: scheduler,
                reduce: { state, event in
                    state += event
                },
                feedbacks: [.just(effects: Observable.interval(.milliseconds(10), scheduler: scheduler).do(onDispose: { isDisposed = true }))]
            )
            sut = deinitSut
            scheduler.advanceTo(10)
            sut?.asObservable().subscribe(observer).disposed(by: disposeBag)
            scheduler.advanceTo(20)
        }
        scheduler.start()

        XCTAssertNil(sut)
        XCTAssertTrue(isDisposed)
        XCTAssertTrue(observer.events.count > 1)
    }
}

// MARK: - Feedbacks

class FeedbacksTests: XCTestCase {
    func test_withLatestState() {
        let scheduler = TestScheduler(initialClock: 0)
        let disposeBag = DisposeBag()
        let observer = scheduler.createObserver(String.self)
        let events = PublishSubject<String>()

        var recordedStates = [String]()
        var disposedCount = 0
        let sut = FeedbackSystem<String, String>(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                .just(effects: events),
                .withLatest(state: { state in
                    state.compactMap {
                        recordedStates.append($0)
                        if $0 == "initial" {
                            return "a"
                        } else if $0.hasSuffix("a") {
                            return "b"
                        } else if $0.hasSuffix("b") {
                            return "c"
                        } else if $0.hasSuffix("final") {
                            return "z"
                        }
                        return nil
                    }
                }, effects: { value in
                    Observable.from(["1", "2", "3"].map { $0 + "-" + value }).do(onDispose: { disposedCount += 1 })
                })
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(50)

        events.onNext("final")
        // even though we complete it, it shouldn't affect other feedbacks
        events.onCompleted()
        scheduler.advanceTo(60)

        let expected = [
            "initial",                           // intial value
            "initial_1-a",                       // first value from the effect
            "initial_1-a_1-b",                   // first value from the new effect, as previous effect was dismissed
            "initial_1-a_1-b_1-c",               // first value from the new effect, as previous effect was dismissed
            "initial_1-a_1-b_1-c_2-c",           // now since we return nil inside `compactMap` for the last state update,
            "initial_1-a_1-b_1-c_2-c_3-c",       // we ignore it and don't produce new value, hence don't dismiss old or create new effect
            "initial_1-a_1-b_1-c_2-c_3-c_final", // after they finish, we produce event from a different feedback

            "initial_1-a_1-b_1-c_2-c_3-c_final_1-z",        // still emitted even though events feedback was completed
            "initial_1-a_1-b_1-c_2-c_3-c_final_1-z_2-z",
            "initial_1-a_1-b_1-c_2-c_3-c_final_1-z_2-z_3-z"
        ]
        XCTAssertRecordedElements(observer.events, expected)

        // now we also check that we don't receive states twice for state update and event update, but only once (inside withLatest)
        XCTAssertEqual(recordedStates, expected)

        // withLatest effect should be disposed 4 times for each letter - a, b, c, z
        XCTAssertEqual(disposedCount, 4)
    }

    func test_withLatestEvents() {
        let scheduler = TestScheduler(initialClock: 0)
        let disposeBag = DisposeBag()
        let observer = scheduler.createObserver(String.self)
        let events = PublishSubject<String>()

        var recordedEvents = [String]()
        var disposedCount = 0
        let sut = FeedbackSystem<String, String>(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                .just(effects: events),
                .withLatest(events: { events in
                    events.do(onNext: { recordedEvents.append($0) }).compactMap {
                        if $0 == "run" {
                            return "a"
                        } else if $0.hasSuffix("a") {
                            return "b"
                        } else if $0.hasSuffix("b") {
                            return "c"
                        } else if $0.hasSuffix("final") {
                            return "z"
                        }
                        return nil
                    }
                }, effects: { value in
                    Observable.from(["1", "2", "3"].map { $0 + "-" + value }).do(onDispose: { disposedCount += 1 })
                })
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)
        events.onNext("run")
        scheduler.advanceTo(20)

        events.onNext("final")
        // even though we complete it, it shouldn't affect other feedbacks
        events.onCompleted()
        scheduler.advanceTo(30)

        // here same result + "run" event in the beginning
        XCTAssertRecordedElements(observer.events, [
            "initial",
            "initial_run",
            "initial_run_1-a",
            "initial_run_1-a_1-b",
            "initial_run_1-a_1-b_1-c",
            "initial_run_1-a_1-b_1-c_2-c",
            "initial_run_1-a_1-b_1-c_2-c_3-c",
            "initial_run_1-a_1-b_1-c_2-c_3-c_final",
            "initial_run_1-a_1-b_1-c_2-c_3-c_final_1-z",
            "initial_run_1-a_1-b_1-c_2-c_3-c_final_1-z_2-z",
            "initial_run_1-a_1-b_1-c_2-c_3-c_final_1-z_2-z_3-z"
        ])

        // same result as for 'withLatestState' test
        XCTAssertEqual(recordedEvents, ["run", "1-a", "1-b", "1-c", "2-c", "3-c", "final", "1-z", "2-z", "3-z"])

        // withLatest effect should be disposed 4 times for each letter - a, b, c, z
        XCTAssertEqual(disposedCount, 4)
    }

    func test_mergingState() {
        typealias State = Tuple<String, String>
        let scheduler = TestScheduler(initialClock: 0)
        let disposeBag = DisposeBag()
        let observer = scheduler.createObserver(State.self)

        var recordedStates = [State]()
        var disposedCount = 0
        let sut = FeedbackSystem<State, String>(
            initial: State("", ""),
            scheduler: scheduler,
            reduce: { state, event in
                switch event {
                case "a": state.a += event
                case "b": state.b += event
                default: break
                }
            },
            feedbacks: [
                .merging(state: { state in
                    state.compactMap {
                        recordedStates.append($0)
                        if $0.a.isEmpty {
                            return "a"
                        } else if $0.b.isEmpty {
                            return "b"
                        }
                        return nil
                    }
                }, effects: { value in
                    Observable.from(repeatElement(value, count: 3)).do(onDispose: { disposedCount += 1 })
                })
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.start()

        // feedbacks produce events one after another in same order they were started, hence state updates are coming similarly
        let expected = [
            State("", ""),
            State("a", ""),
            State("a", "b"),
            State("aa", "b"),
            State("aa", "bb"),
            State("aaa", "bb"),
            State("aaa", "bbb")
        ]
        XCTAssertRecordedElements(observer.events, expected)

        // now we also check that we don't receive states twice for state update and event update, but only once (inside withLatest)
        XCTAssertEqual(recordedStates, expected)

        // merging effect should be disposed 2 times for each letter - a, b
        XCTAssertEqual(disposedCount, 2)
    }

    func test_mergingEvents() {
        typealias State = Tuple<String, String>
        let scheduler = TestScheduler(initialClock: 0)
        let disposeBag = DisposeBag()
        let observer = scheduler.createObserver(State.self)
        let events = PublishSubject<String>()

        var recordedEvents = [String]()
        var disposedCount = 0
        let sut = FeedbackSystem<State, String>(
            initial: State("", ""),
            scheduler: scheduler,
            reduce: { state, event in
                switch event {
                case "a": state.a += event
                case "b": state.b += event
                default: break
                }
            },
            feedbacks: [
                .just(effects: events),
                .merging(events: { state in
                    state.compactMap {
                        recordedEvents.append($0)
                        if $0 == "runA" {
                            return "a"
                        } else if $0 == "runB" {
                            return "b"
                        }
                        return nil
                    }
                }, effects: { value in
                    Observable.from(repeatElement(value, count: 3)).do(onDispose: { disposedCount += 1 })
                })
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)
        events.onNext("runA")
        events.onNext("runB")
        scheduler.start()

        // don't care about intermediate steps here, final result is correct
        XCTAssertRecordedElements(observer.events.suffix(1), [State("aaa", "bbb")])

        // events are not coming nicely one after another, i.e. (a,b,a,b,a,b ...)
        // because second external event (runB) delays it by previous + current event
        XCTAssertEqual(recordedEvents, ["runA", "a", "runB", "a", "b", "a", "b", "b"])

        // merging effect should be disposed 2 times for each letter - a, b
        XCTAssertEqual(disposedCount, 2)
    }

    func test_imperative() {
        typealias State = Tuple<String, String>
        let scheduler = TestScheduler(initialClock: 0)
        let disposeBag = DisposeBag()
        let observer = scheduler.createObserver(State.self)
        let events = PublishSubject<String>()

        var recordedInputs = [(state: State, event: String)]()
        let sut = FeedbackSystem<State, String>(
            initial: State("", ""),
            scheduler: scheduler,
            reduce: { state, event in
                switch event {
                case "a": state.a += event
                case "b": state.b += event
                default: break
                }
            },
            feedbacks: [
                .just(effects: events),
                .imperative(effects: { callback in
                    return { state, event in
                        recordedInputs.append((state, event))
                        // reacting to both - events and then to state updates
                        if event == "run" {
                            callback("a")
                            callback("b")
                        }
                        // will send these callbacks if runA and runB were processed (there's at least 1 character of a or b)
                        if event == "a" && 1..<3 ~= state.a.count {
                            callback("a")
                        }
                        if event == "b" && 1..<3 ~= state.b.count {
                            callback("b")
                        }
                    }
                })
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)

        events.onNext("run")
        scheduler.start()

        XCTAssertRecordedElements(observer.events, [
            State("", ""),        // initial
            State("", ""),        // 'run' event
            State("a", ""),       // 'a' event
            State("a", "b"),      // 'b' event, and so on ...
            State("aa", "b"),
            State("aa", "bb"),
            State("aaa", "bb"),
            State("aaa", "bbb"),
        ])

        // we see that imperative feedback receives event with the state that was already updated by reducer
        // however 'run' event didn't cause any state update, so it just comes with the current state
        XCTAssertEqual(recordedInputs.map(Tuple.init), [
            Tuple(State("", ""), "run"),
            Tuple(State("a", ""), "a"),
            Tuple(State("a", "b"), "b"),
            Tuple(State("aa", "b"), "a"),
            Tuple(State("aa", "bb"), "b"),
            Tuple(State("aaa", "bb"), "a"),
            Tuple(State("aaa", "bbb"), "b")
        ])
    }

    func test_imperativeFeedback_shouldReceiveUpdatesOnCorrectScheduler() {
        let exp = expectation(description: "test_imperativeFeedback_shouldReceiveUpdatesOnCorrectScheduler")
        // 3 for state updates + 1 for comlpetion + 2 for feedback events + 1 for imperative feedback setup
        exp.expectedFulfillmentCount = 7
        let disposeBag = DisposeBag()
        let sut = FeedbackSystem(
            initial: "initial",
            scheduler: SerialDispatchQueueScheduler(qos: .userInitiated),
            reduce: { state, event in
                state = state + "_" + event
            },
            feedbacks: [
                .just(effects: .just("run")), // making sure run event will be sent once system is fully setup on async scheduler
                .imperative(effects: { callback in
                    XCTAssertTrue(DispatchQueue.isUserInitiated)
                    exp.fulfill()

                    return { state, event in
                        if event == "run" {
                            callback("a")
                        }

                        XCTAssertTrue(DispatchQueue.isUserInitiated)
                        exp.fulfill()
                    }
                })
            ]
        )
        // listening to updates straight from the system
        var results = [String]()
        sut.asObservable()
            .take(3)
            .subscribe(onNext: {
                results.append($0)

                XCTAssertTrue(DispatchQueue.isUserInitiated)
                exp.fulfill()
            }, onCompleted: {
                XCTAssertTrue(DispatchQueue.isUserInitiated)
                exp.fulfill()
            })
            .disposed(by: disposeBag)

        waitForExpectations(timeout: 5.0) { e in
            XCTAssertEqual(results, ["initial", "initial_run", "initial_run_a"])
        }
    }

    func test_lensingFeedback() {
        let scheduler = TestScheduler(initialClock: 0)
        let disposeBag = DisposeBag()
        let observer = scheduler.createObserver(String.self)
        let events = PublishSubject<String>()

        var recordedStates = [String]()
        var disposedCount = 0
        let sut = FeedbackSystem<String, String>(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                .just(effects: events),
                .lensing(state: {
                    recordedStates.append($0)
                    if $0 == "initial" {
                        return "a"
                    } else if $0.hasSuffix("a") {
                        return "b"
                    } else if $0.hasSuffix("b") {
                        return "c"
                    } else if $0.hasSuffix("final") {
                        return "z"
                    }
                    return nil
                }, effects: { value in
                    Observable.from(["1", "2", "3"].map { $0 + "-" + value }).do(onDispose: { disposedCount += 1 })
                })
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(50)

        events.onNext("final")
        // even though we complete it, it shouldn't affect other feedbacks
        events.onCompleted()
        scheduler.start()

        let expected = [
            "initial",                           // intial value
            "initial_1-a",                       // first value from the effect
            "initial_1-a_1-b",                   // first value from the new effect, as previous effect was dismissed
            "initial_1-a_1-b_1-c",               // first value from the new effect, as previous effect was dismissed
                                                 // however there's no 2/3-c, because we return `nil` which kills existing effect
            "initial_1-a_1-b_1-c_final",         // after they finish, we produce event from a different feedback
            "initial_1-a_1-b_1-c_final_1-z"      // still emitted even though events feedback was completed
                                                 // same here, no 2/3-z because effect is killed by returned `nil`
        ]
        XCTAssertRecordedElements(observer.events, expected)

        // now we also check that we don't receive states twice for state update and event update, but only once (inside lensing)
        XCTAssertEqual(recordedStates, expected)

        // lensing effect should be disposed 4 times for each letter - a, b, c, z
        XCTAssertEqual(disposedCount, 4)
    }

    func test_extractingFeedback() {
        let scheduler = TestScheduler(initialClock: 0)
        let disposeBag = DisposeBag()
        let observer = scheduler.createObserver(String.self)
        let events = PublishSubject<String>()

        var recordedEvents = [String]()
        var disposedCount = 0
        let sut = FeedbackSystem<String, String>(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                .just(effects: events),
                .extracting(payload: {
                    recordedEvents.append($0)
                    if $0.hasPrefix("run") {
                        return String($0.suffix(1))
                    }
                    return nil
                }, effects: { value in
                    Observable.from(["1", "2", "3"].map { $0 + "-" + value }).do(onDispose: { disposedCount += 1 })
                })
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)

        events.onNext("run-a")
        events.onNext("run-b")
        events.onNext("run-c")
        // even though we complete it, it shouldn't affect other feedbacks
        events.onCompleted()
        scheduler.start()

        let expected = [
            "initial",                               // intial value
            "initial_run-a",                         // run-a event
            "initial_run-a_1-a",                     // has run prefix, so we send 1-a event
                                                     // effect for 'a' is killed because no more event has 'run' prefix
            "initial_run-a_1-a_run-b",               // run-b event, even if effect for 'a' was running,
                                                     // it would be killed here, because we produce new value 'b'
            "initial_run-a_1-a_run-b_1-b",           // same here, created 1-b, then 'b' effect is killed and 'c' effect is created
            "initial_run-a_1-a_run-b_1-b_run-c",
            "initial_run-a_1-a_run-b_1-b_run-c_1-c", // in the end, 'c' effect is killed because no 'run' prefix and we produce `nil`
        ]
        XCTAssertRecordedElements(observer.events, expected)

        // now we also check that we don't receive states twice for state update and event update, but only once (inside lensing)
        XCTAssertEqual(recordedEvents, ["run-a", "1-a", "run-b", "1-b", "run-c", "1-c"])

        // extracting effect should be disposed 3 times for each letter - a, b, c
        XCTAssertEqual(disposedCount, 3)
    }

    func test_lensingSkippingRepeatedFeedback() {
        let scheduler = TestScheduler(initialClock: 0)
        let disposeBag = DisposeBag()
        let observer = scheduler.createObserver(String.self)
        let events = PublishSubject<String>()

        var recordedStates = [String]()
        var disposedCount = 0
        let sut = FeedbackSystem<String, String>(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                .just(effects: events),
                .lensingSkippingRepeated(state: {
                    recordedStates.append($0)
                    if $0.hasSuffix("a") {
                        return "a"
                    } else if $0.hasSuffix("b") {
                        return "b"
                    } else if $0.hasSuffix("c") {
                        return "c"
                    } else if $0.hasSuffix("final") || $0.hasSuffix("z") {
                        return "z"
                    }
                    return nil
                }, effects: { value in
                    Observable.from(["1", "2", "3"].map { $0 + "-" + value }).do(onDispose: { disposedCount += 1 })
                })
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)

        events.onNext("a")
        scheduler.advanceTo(20)

        events.onNext("b")
        scheduler.advanceTo(30)

        events.onNext("c")
        scheduler.advanceTo(40)

        events.onNext("final")
        scheduler.advanceTo(50)

        // even though we complete it, it shouldn't affect other feedbacks
        events.onCompleted()
        scheduler.start()

        let expected = [
            "initial",                                          // initial
            "initial_a",                                        // a event
            "initial_a_1-a",                                    // 1st, 2nd and 3rd values from the effect
            "initial_a_1-a_2-a",                                // note that all of them executed instead of stopping at 1-a
            "initial_a_1-a_2-a_3-a",                            // because we're skipping repeated "a" value returned from transform
                                                                // and original effect keeps living

            "initial_a_1-a_2-a_3-a_b",                          // same for b, c and z events
            "initial_a_1-a_2-a_3-a_b_1-b",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c",

            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c_final",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c_final_1-z", // still emitted even though events feedback was completed
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c_final_1-z_2-z",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c_final_1-z_2-z_3-z"

        ]
        XCTAssertRecordedElements(observer.events, expected)

        // now we also check that we don't receive states twice for state update and event update, but only once (inside lensingSkippingRepeated)
        XCTAssertEqual(recordedStates, expected)

        // lensingSkippingRepeated effect should be disposed 4 times for each letter - a, b, c, z
        XCTAssertEqual(disposedCount, 4)
    }

    func test_extractingSkippingRepeatedFeedback() {
        let scheduler = TestScheduler(initialClock: 0)
        let disposeBag = DisposeBag()
        let observer = scheduler.createObserver(String.self)
        let events = PublishSubject<String>()

        var recordedEvents = [String]()
        var disposedCount = 0
        let sut = FeedbackSystem<String, String>(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                .just(effects: events),
                .extractingSkippingRepeated(payload: {
                    recordedEvents.append($0)
                    if $0.hasSuffix("a") {
                        return "a"
                    } else if $0.hasSuffix("b") {
                        return "b"
                    } else if $0.hasSuffix("c") {
                        return "c"
                    }
                    return nil
                }, effects: { value in
                    Observable.from(["1", "2", "3"].map { $0 + "-" + value }).do(onDispose: { disposedCount += 1 })
                })
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)

        events.onNext("run-a")
        scheduler.advanceTo(20)

        events.onNext("run-b")
        scheduler.advanceTo(30)

        events.onNext("run-c")
        // even though we complete it, it shouldn't affect other feedbacks
        events.onCompleted()
        scheduler.start()

        let expected = [
            "initial",                                          // initial
            "initial_run-a",                                    // run-a event
            "initial_run-a_1-a",                                // 1st, 2nd and 3rd values from the effect
            "initial_run-a_1-a_2-a",                            // note that all of them executed instead of stopping at 1-a
            "initial_run-a_1-a_2-a_3-a",                        // because we're skipping repeated "a" value returned from transform
                                                                // and original effect keeps living

            "initial_run-a_1-a_2-a_3-a_run-b",                  // same for b and c
            "initial_run-a_1-a_2-a_3-a_run-b_1-b",
            "initial_run-a_1-a_2-a_3-a_run-b_1-b_2-b",
            "initial_run-a_1-a_2-a_3-a_run-b_1-b_2-b_3-b",
            "initial_run-a_1-a_2-a_3-a_run-b_1-b_2-b_3-b_run-c",
            "initial_run-a_1-a_2-a_3-a_run-b_1-b_2-b_3-b_run-c_1-c",
            "initial_run-a_1-a_2-a_3-a_run-b_1-b_2-b_3-b_run-c_1-c_2-c",
            "initial_run-a_1-a_2-a_3-a_run-b_1-b_2-b_3-b_run-c_1-c_2-c_3-c",

        ]
        XCTAssertRecordedElements(observer.events, expected)

        XCTAssertEqual(recordedEvents, ["run-a", "1-a", "2-a", "3-a", "run-b", "1-b", "2-b", "3-b", "run-c", "1-c", "2-c", "3-c"])

        // extractingSkippingRepeated effect should be disposed 3 times for each letter - a, b, c
        XCTAssertEqual(disposedCount, 3)
    }

    func test_skippingRepeatedFeedback() {
        let scheduler = TestScheduler(initialClock: 0)
        let disposeBag = DisposeBag()
        let observer = scheduler.createObserver(Int.self)
        let events = PublishSubject<Int>()

        var disposedCount = 0
        let sut = FeedbackSystem<Int, Int>(
            initial: 1,
            scheduler: scheduler,
            reduce: { state, event in
                state *= event
            },
            feedbacks: [
                .just(effects: events),
                .skippingRepeated(state: { 0 ..< 10000 ~= $0 }, effects: { _ in Observable.just(10).do(onDispose: { disposedCount += 1 }) }),
                .skippingRepeated(state: { 0 ..< 10000 ~= $0 }, effects: { _ in Observable.just(20).do(onDispose: { disposedCount += 1 }) }),
                .skippingRepeated(state: { 0 ..< 10000 ~= $0 }, effects: { _ in Observable.just(30).do(onDispose: { disposedCount += 1 }) }),
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)

        events.onNext(10)

        // even though we complete it, it shouldn't affect other feedbacks
        events.onCompleted()
        scheduler.start()

        XCTAssertRecordedElements(observer.events, [
            1,                                  // initial
            10, 200, 6_000,                     // each effects is launched only once, as their predicate is always 'true'
            60_000,                             // sending event 10
            600_000, 12_000_000, 360_000_000    // each effects is launched only once, as their predicate is always 'false' now
        ])

        // skippingRepeated effects should be disposed 6 times for each skippingRepeated feedback (3 of them, 2 times each)
        XCTAssertEqual(disposedCount, 6)
    }

    func test_firstValueAfterNilFeedback() {
        let scheduler = TestScheduler(initialClock: 0)
        let disposeBag = DisposeBag()
        let observer = scheduler.createObserver(String.self)
        let events = PublishSubject<String>()

        var disposedCount = 0
        let sut = FeedbackSystem<String, String>(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                .just(effects: events),
                .firstValueAfterNil(state: {
                    $0.hasSuffix("a") && !$0.hasSuffix("3-a") ? true : nil
                }, effects: { _ in
                    Observable.from(["1", "2", "3", "4"].map { $0 + "-a" }).do(onDispose: { disposedCount += 1 })
                }),
                .firstValueAfterNil(state: {
                    $0.hasSuffix("b") && !$0.hasSuffix("3-b") ? true : nil
                }, effects: { _ in
                    Observable.from(["1", "2", "3", "4"].map { $0 + "-b" }).do(onDispose: { disposedCount += 1 })
                }),
                .firstValueAfterNil(state: {
                    $0.hasSuffix("c") && !$0.hasSuffix("3-c") ? true : nil
                }, effects: { _ in
                    Observable.from(["1", "2", "3", "4"].map { $0 + "-c" }).do(onDispose: { disposedCount += 1 })
                }),
                .firstValueAfterNil(state: {
                    ($0.hasSuffix("final") || $0.hasSuffix("z"))  && !$0.hasSuffix("3-z") ? true : nil
                }, effects: { _ in
                    Observable.from(["1", "2", "3", "4"].map { $0 + "-z" }).do(onDispose: { disposedCount += 1 })
                }),
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)

        events.onNext("a")
        scheduler.advanceTo(20)

        events.onNext("b")
        scheduler.advanceTo(30)

        events.onNext("c")
        scheduler.advanceTo(40)

        events.onNext("final")
        scheduler.advanceTo(50)

        // even though we complete it, it shouldn't affect other feedbacks
        events.onCompleted()
        scheduler.start()

        let expected = [
            "initial",                                          // initial
            "initial_a",                                        // a event
            "initial_a_1-a",                                    // 1st, 2nd and 3rd values from the effect
            "initial_a_1-a_2-a",                                // note that all of them were executed instead of stopping at 1-a
            "initial_a_1-a_2-a_3-a",                            // because we're starting an effect only when predicate becomes true
                                                                // and original effect keeps living

            "initial_a_1-a_2-a_3-a_b",                          // same for b, c and z events
            "initial_a_1-a_2-a_3-a_b_1-b",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c",

            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c_final",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c_final_1-z", // still emitted even though events feedback was completed
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c_final_1-z_2-z",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c_final_1-z_2-z_3-z"

        ]
        XCTAssertRecordedElements(observer.events, expected)

        // firstValueAfterNil effect should be disposed 4 times for each letter - a, b, c, z
        XCTAssertEqual(disposedCount, 4)
    }

    func test_whenBecomesTrueFeedback() {
        let scheduler = TestScheduler(initialClock: 0)
        let disposeBag = DisposeBag()
        let observer = scheduler.createObserver(String.self)
        let events = PublishSubject<String>()

        var disposedCount = 0
        let sut = FeedbackSystem<String, String>(
            initial: "initial",
            scheduler: scheduler,
            reduce: { state, event in
                state += "_" + event
            },
            feedbacks: [
                .just(effects: events),
                .whenBecomesTrue(state: {
                    $0.hasSuffix("a") && !$0.hasSuffix("3-a")
                }, effects: { _ in
                    Observable.from(["1", "2", "3", "4"].map { $0 + "-a" }).do(onDispose: { disposedCount += 1 })
                }),
                .whenBecomesTrue(state: {
                    $0.hasSuffix("b") && !$0.hasSuffix("3-b")
                }, effects: { _ in
                    Observable.from(["1", "2", "3", "4"].map { $0 + "-b" }).do(onDispose: { disposedCount += 1 })
                }),
                .whenBecomesTrue(state: {
                    $0.hasSuffix("c") && !$0.hasSuffix("3-c")
                }, effects: { _ in
                    Observable.from(["1", "2", "3", "4"].map { $0 + "-c" }).do(onDispose: { disposedCount += 1 })
                }),
                .whenBecomesTrue(state: {
                    ($0.hasSuffix("final") || $0.hasSuffix("z"))  && !$0.hasSuffix("3-z")
                }, effects: { _ in
                    Observable.from(["1", "2", "3", "4"].map { $0 + "-z" }).do(onDispose: { disposedCount += 1 })
                }),
            ]
        )

        sut.asObservable().subscribe(observer).disposed(by: disposeBag)
        scheduler.advanceTo(10)

        events.onNext("a")
        scheduler.advanceTo(20)

        events.onNext("b")
        scheduler.advanceTo(30)

        events.onNext("c")
        scheduler.advanceTo(40)

        events.onNext("final")
        scheduler.advanceTo(50)

        // even though we complete it, it shouldn't affect other feedbacks
        events.onCompleted()
        scheduler.start()

        let expected = [
            "initial",                                          // initial
            "initial_a",                                        // a event
            "initial_a_1-a",                                    // 1st, 2nd and 3rd values from the effect
            "initial_a_1-a_2-a",                                // note that all of them were executed instead of stopping at 1-a
            "initial_a_1-a_2-a_3-a",                            // because we're starting an effect only when predicate becomes true
                                                                // and original effect keeps living

            "initial_a_1-a_2-a_3-a_b",                          // same for b, c and z events
            "initial_a_1-a_2-a_3-a_b_1-b",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c",

            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c_final",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c_final_1-z", // still emitted even though events feedback was completed
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c_final_1-z_2-z",
            "initial_a_1-a_2-a_3-a_b_1-b_2-b_3-b_c_1-c_2-c_3-c_final_1-z_2-z_3-z"

        ]
        XCTAssertRecordedElements(observer.events, expected)

        // withLatest effect should be disposed 4 times for each letter - a, b, c, z
        XCTAssertEqual(disposedCount, 4)
    }
}

// MARK: - Utils

fileprivate extension DispatchQueue {
    private static var token: DispatchSpecificKey<()> = {
        let key = DispatchSpecificKey<()>()
        DispatchQueue.global(qos: .userInitiated).setSpecific(key: key, value: ())
        return key
    }()

    static var isUserInitiated: Bool {
        return DispatchQueue.getSpecific(key: token) != nil
    }
}

fileprivate final class Atomic<Value> {
    private let queue = DispatchQueue(label: "Atomic serial queue", attributes: .concurrent)
    private var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        queue.sync { self._value }
    }

    func mutate(_ transform: (inout Value) -> Void) {
        queue.sync(flags: .barrier) {
            transform(&self._value)
        }
    }
}

fileprivate struct Tuple<T, U>: CustomDebugStringConvertible {
    var a: T, b: U

    init(_ a: T, _ b: U) {
        (self.a, self.b) = (a, b)
    }

    var debugDescription: String {
        "(\(a), \(b))"
    }
}

extension Tuple: Equatable where T: Equatable, U: Equatable {}
