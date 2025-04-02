# 🖼️ UI

A set of components to aid structuring logic in unidirectional manner when building UI.

## Overview

Idea of splitting UI from its respective logic is not new, so we won't go deep in it here.

A screen consists of 3 main components:
 - WhimScenePresentation - an interface describing presentation layer (i.e. UIViewController).
 - WhimSceneStore - an interface describing business logic layer with its state.
 - WhimSceneBinding - a small utility to bind them both together so that Store's state updates are passed down to the presentation, and so that presentation can pass actions to the Store.

### WhimScenePresentation

The interface is pretty simple in a nutshell and the approach should be familiar to those who're using SwiftUI:
```swift
protocol WhimScenePresentation {
  associatedtype State
  associatedtype Action

  var output: (Action) -> Void { get set }

  func render(state: State)
}
```
All it can do is receive a State to render and delegate an action back.
It is up to a presentation component to figure out how to perform rendering - either to render everything every time a new state comes in, or to make a diff between old and new states and optimize rendering based on delta.

### WhimSceneStore

Store has the same idea as Service from the <doc:Architecture> document.
```swift
protocol WhimSceneStore: AnyObject {
  associatedtype State
  associatedtype Action
  associatedtype Route

  var state: Observable<State> { get }
  var routes: Observable<Route> { get }

  func dispatch(_ action: Action)
}
```
Except it has an extra observable property in its interfaces - **routes**.
Routes can be thought of as a callback on top to notify that the screen wants to be dismissed or navigated somewhere further.
There're two basic principles when thinking of routing:
 - The one who presents view-controller, is responsible for dismissing it.
 - Routing is derived from state or action.

I think that the shortcut UIKit took for dismissing or popping a screen by itself, often shoots us in the leg.
A screen that is being presented often doesn't know how it was presented, and it's usually a part of a navigation which has its own logic to how and when present other screens. Hence following a basic resource ownership model - if you allocate a memory for the object - you're responsible for deallocating it, if you open a file - you're responsible for closing it, if you present a screen - you're responsible for closing it.

And the reason routes belong to the Store, is that Store owns the business logic and can make a decision when a screen is ready to be dismissed or switch to another screen.

### WhimSceneBinding

Bindings is a utility that binds Store's state updates to Presentation's rendering, and Presentation's output actions to Store's dispatch method.

## Topics

- ``WhimScenePresentation``
- ``WhimSceneStore``
- ``WhimSceneBinding``
- ``WhimScenePresentationViewController``
- ``NonePresentation``
