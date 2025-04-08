# ``WhimCoreTest``

Utilities to help testing WhimCore Architecture components.

## Overview

Allows testing unidirectional `WhimCore.FeedbackSystem` as a regular synchronous code by leveraging `RxTest.TestScheduler` ability to advance through virtual time.

Testing with feedback-system is pretty easy. There's `StoreVerification` utility in `WhimCoreTest` module which helps to setup any service or store based on feedback-system with test-scheduler.
It follows [given-when-then](https://martinfowler.com/bliki/GivenWhenThen.html) or [arrange-act-assert](https://wiki.c2.com/?ArrangeActAssert) pattern for describing unit-test.

First, you need to setup a service you whish to test within `given` block by injecting a provided test-scheduler into your service and returning service with its observable state.
```swift
let sut = StoreVerification<AuthService, AuthService.State>(given: { scheduler in
  let store = AuthService(scheduler: scheduler, service: APIServiceMock())
  return (store, store.state)
})
```

Second, you may call `verify` function with two blocks:
- In `when` block you run actual logic that you're willing to test
- In `then` block you run actual assertion

```swift
sut.verify(
  when: { store, scheduler in
    // you start workflow by advancing scheduler
    // so that system would start working
    scheduler.advanceBy(10)
    // and then rotate - performing work and advancing scheduler
    store.dispatch(.authenticate(credentials))
    // finish by advancing scheduler so that last step is executed
    scheduler.advanceBy(10)
  },
  then: { events in
    // RxTest provides custom assertions
    // to easily verify events with actual states
    // when other info (their time) not needed
    XCTAssertRecordedElements(events, [
      .action(.authenticate(credentials)),
      .didAuthenticate(.success(token))
    ])
  }
)
```

Notice how you always keep advancing the scheduler in the `when` block.
Test scheduler is basically a virtual scheduler and it treats time as a virtual unit. Virtual time doesn't advance by itself, thus no work is executed on a scheduler unless you explicitly advance its time.
Don't worry if it sounds confusing from a first sight. There's an amazing explanation of how it works in [Testing Your RxSwift Code](https://www.raywenderlich.com/7408-testing-your-rxswift-code#toc-anchor-006) article.
In short, you need to advance test-scheduler by a little bit, after each bit of work you want to execute. This approach scales to any bespoke flexibility in testing asynchronous code you dream up.

You receive all recorded events with state updates in `then` block. Event is basically a pair of state and virtual time point when that state was updated. There're custom `XCTest` and `Nimble` assertions, that allow you to simplify verification of recorded states.

You can call `verify` block multiple times to test different behavior, but be aware that each verification you perform on a single instance of `StoreVerification` will continue from where previous one left off, as it's using still the same service and virtual timer.
You can even split it into separate `when` or `then` calls. It might be handy in `Quick` tests, where you can have nested contexts, and each adds some behavior using `when` block.


## Topics

### Store verification

- ``verifyStore(schedulerResolution:given:when:then:)``
- ``StoreVerification``

### Recorded Events

- ``RecordedEvent``
- ``RecordedEvents``

### XCTest Matchers

- ``XCTAssertRecordedElement(_:_:file:line:)``
- ``XCTAssertRecordedElements(_:_:file:line:)``

### Quick & Nimble Matchers

- ``beNilElement()``
- ``equalElement(_:)``
- ``equalElements(_:)``
- ``beIdenticalToElement(_:)``
