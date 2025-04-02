# 🛤️ Navigation

A custom Navigation Stack that handles multipart (top/bottom) screens along with regular screens, allowing nested stacks. 

## Overview

To understand why someone would need to build their own navigation stack, you need to understand the requirements to the app we were building :-)

Most of the user experience was revolving around a map. So pretty much majority of the screens related to MaaS orders had the same structure - a top bar, a bottom card that could slide up and down and a map in the middle underneath them. Sometimes those screens would stack on top of each other which meant keeping all those maps in memory, then there should've been a common way to work with maps, and moving between screens was not smooth as every screen was showing its own map, when in reality only top and bottom parts should've been moving.

> We're talking more about maps in the <doc:Map> document.

So the question was how we can keep the same map all the time visible for such flows, while only moving top and bottom parts, yet still being able to treat each screen as a separate component with its own logic. And how we can combine both regular screens and such "multipart" screens in the same navigation stack.

Well, the answer - we don't, since UIKit doesn't provide such tools out of the box with UINavigationStack. Hence I explored the idea of a custom naviation stack that would work exactly how we wanted (including the ability to nest custom navigation stacks for a smooth flow management, but that's later).

---

### ⛓️ WhimCore Responder Chain

#### WhimSceneViewController

Quite naturally we start with the notion of our own view controller that can be either a fullscreen regular component or a multipart (top & bottom) component.

```swift
enum WhimSceneViewController {
  case fullscreen(UIViewController)
  case multipart(top: UIViewController, bottom: UIViewController)
}
```

Now we need to find a way to render it, and since we're going for a custom implementation, embedded view controllers make sense. However building a whole navigation stack would require a bit more than that.

#### WhimScene

So let's have an abstraction over our custom view controller representation, we call it **WhimScene**. In our world WhimScene is the same as UIViewController in the regular world. Which means it can have its own hierarchy (i.e. a screen pushed onto a navigation stack).

```swift
protocol WhimScene {
  var parent: WhimScene? { get set } // a weak reference
  var viewController: WhimSceneViewController { get }
}
```
Now the fun part - since we can have any amount of nesting and it's all implemented via embedding wrapped UIViewControllers, then who will actually embed and render the view controller which needs to be presented to the user?

#### WhimSceneResponder

Correct, we'll just implement our own responder chain, even though it's pretty basic.

```swift
protocol WhimSceneResponder: AnyObject {
  var nextSceneResponder: WhimSceneResponder? { get }

  func present(scene: WhimScene)
}

extension WhimScene: WhimSceneResponder {
  var nextSceneResponder: WhimSceneResponder? {
    // and usually it's a parent
    parent
  }
}
```

Now we have a way to delegate rendering to someone on top.
Let's create that someone!

#### WhimSceneContainerViewController

Basically as you could've guessed it can be anyone who's a WhimScene (WhimSceneResponder) and has an ability to do something with a UIViewController which will be passed to the `present` method.

So we can have a UIViewController which is a WhimScene and we only need to implement the way how either fullscreen is embedded or multipart top & bottom are embedded.

```swift
open class WhimSceneContainerViewController: UIViewController, WhimScene {
  ...
}
```

Now we can place WhimSceneContainerViewController anywhere in our app - either as a root view controller of app delegate's window or as a view controller of one of our app features - its design is pretty lightweight and doesn't require anything else, so it can easily coexist in any part of the app.

#### WhimSceneNavigationStack

Finally we can implement our own navigation stack, which is honestly quiet straightforward.
It's basically a WhimScene and has a stack of WhimScenes, which also means that it can contain other stacks which contain other stacks... And it opens great possibilities as how to control flows!

```swift
open class WhimSceneNavigationStack: WhimScene {
  public final private(set) var scenes: [WhimScene] = []

  public func present(scene: WhimScene) {
    ...
  }
}
```

---

### 🚃 WhimCore Flows

There's no separate abstraction to flows here because the idea is so simple and straightforward. You can often find them called as **Coordinators** and sometimes they can be really hard to cook well. However if you treat your navigation stack as a coordinator, it immidiately clicks - you have access to the state of your flow through a navigation stack, you control which scenes are shown and their order and you facilitate the data they pass to one another. I was inspired by these two articles and I find this idea simple and effective:
- [Controller Hierarchies](https://sandofsky.com/patterns/controller-hierarchies/)
- [Going Back To The Roots](https://ilya.puchka.me/going-back-to-the-roots/)

So if you have a complicated flow i.e. booking a rental car, which can take a few screens to accomplish, you can have a CarBookingFlow coordinator inherited from a WhimSceneNavigationStack and facilitate the flow there easily.

```swift
final class CarBookingFlow: WhimSceneNavigationStack {
  private let router: (CarBookingFlowRoute) -> Void

  init(intent: CarBookingFlowIntent, router: @escaping (CarBookingFlowRoute) -> Void) {
    self.router = router
    super.init([])

    switch intent {
    case .locationPicker: push(locationPicker())
    case .datesPicker: push(datesPicker())
    }
  }

  ...
}

enum CarBookingFlowIntent {
  case locationPicker, datesPicker
}

enum CarBookingFlowRoute {
  case dismiss, carBooked(ReservationDetails)
}
```

---

### 🎞️ Animations

#### WhimSceneAnimatedTransitions

Last but not the least is custom animations which we would be able to create ourselves.

```swift
public protocol WhimSceneAnimatedTransitioning {
  func transition(
    from: WhimSceneViewController?,
    to: WhimSceneViewController,
    in container: UIView,
    completion: @escaping (Bool) -> Void
  )
}
```

There's a namespace `WhimSceneAnimatedTransitions` which contains following animations:
- ``WhimSceneAnimatedTransitions/Push``
- ``WhimSceneAnimatedTransitions/Pop``
- ``WhimSceneAnimatedTransitions/Modal`` (present | dismiss | swap)
- ``WhimSceneAnimatedTransitions/Fade``
- ``WhimSceneAnimatedTransitions/Circular``
- ``WhimSceneAnimatedTransitions/None``

Modal is the trickiest one because we're going both directions with multipart WhimScene and it has variety of scenarios based on which scene we're going from and to and which direction each top & bottom should go :-)

The only downside is that we don't yet support interactive transitions because of the custom embedding of WhimScene.

## Topics

- ``WhimSceneViewControllerValue``
- ``WhimSceneViewController``
- ``WhimScene``
- ``WhimSceneResponder``
- ``WhimSceneRelationship``
- ``WhimSceneContainerViewController``
- ``WhimSceneNavigationStack``
- ``WhimSceneAnimatedTransitioning``
- ``WhimSceneAnimatedTransitions``
- ``WhimSingleScene``
