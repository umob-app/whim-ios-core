# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WhimCore is an iOS Swift Package providing core utilities and architecture components for iOS applications. It implements a unidirectional reactive architecture based on Feedback Loop patterns, with specialized components for map-based mobile applications.

## Key Architecture Components

### Feedback Loop System
The core architecture is built around a unidirectional data flow pattern:
- **State**: Overall system state (treat as Moore state machine)
- **Event**: Immutable events that trigger state changes
- **Reducer**: Pure functions that handle state transitions based on events
- **Feedback**: Side effects triggered by state changes or events

Key files:
- `Sources/WhimCore/Architecture/FeedbackSystem.swift` - Core feedback system implementation
- `Sources/WhimCore/Architecture/AbstractService.swift` - Base class for services using the pattern

### Custom Navigation Stack
Implements a custom navigation system for map-based apps with multipart screens (top/bottom panels with shared map):
- **WhimScene**: Equivalent to UIViewController in the regular world, supports hierarchy
- **WhimSceneViewController**: Can be fullscreen or multipart (top + bottom components)
- **WhimSceneResponder**: Custom responder chain for scene presentation

Key files:
- `Sources/WhimCore/Navigation/WhimScene.swift` - Scene abstraction and responder chain
- `Sources/WhimCore/Navigation/WhimSceneNavigationStack.swift` - Custom navigation stack
- `Sources/WhimCore/Navigation/WhimSceneViewController.swift` - View controller wrapper

### Map System
Abstraction layer over MapKit with clustering, overlays, and reactive bindings:
- Map clustering with QuadTree algorithm
- Custom overlays (markers, polygons, polylines)
- Apple Maps integration with reactive extensions

Key directories:
- `Sources/WhimCore/Map/` - Map components and utilities
- `Sources/WhimCore/Map/AppleMaps/` - Apple Maps specific implementations

## Development Commands

### Building and Testing
```bash
# Run tests (uses Quick/Nimble framework)
swift test

# Build for iOS (required for WhimCore due to UIKit dependencies)
scripts/swift-ios-command.sh package build --target WhimCore

# Build for macOS (for WhimCoreTest target)
scripts/swift-macos-command.sh package build --target WhimCoreTest
```

### Documentation
```bash
# Generate and serve DocC documentation locally
scripts/docs
# Then visit http://localhost:8080/documentation

# Generate documentation only
scripts/docs-generate

# Preview documentation (requires generation first)
scripts/docs-preview
```

### Templates
```bash
# Install Xcode templates for creating scenes and services
scripts/templates
```

## Testing Framework

Tests use Quick/Nimble BDD framework with custom testing utilities:
- Test files in `Tests/WhimCoreUnitTests/`
- Custom fakes and random data generators in `Tests/WhimCoreUnitTests/Support/`
- Feedback system testing with RxTest scheduler support

## Dependencies

- **RxSwift 6.5.0**: Reactive programming for the feedback system
- **Swift Collections**: Ordered collections for internal data structures
- **Quick/Nimble**: BDD testing framework
- **SwiftyMock**: Mocking framework for tests

## Project Structure

- `Sources/WhimCore/` - Main library code
  - `Architecture/` - Feedback loop system and base abstractions
  - `Navigation/` - Custom navigation stack implementation
  - `Map/` - Map abstractions and Apple Maps integration  
  - `BottomPanel/` - Sliding bottom panel component
  - `GeoCache/` - Geographic caching and geohashing
  - `Utils/` - Extensions and utility functions
- `Sources/WhimCoreTest/` - Testing utilities library
- `Tests/WhimCoreUnitTests/` - Unit tests
- `WhimCoreDemo/` - Demo Xcode project showing library usage
- `Templates/` - Xcode templates for scenes and services

## Code Conventions

- Use reactive patterns with RxSwift for async operations
- State management through unidirectional Feedback Loop pattern
- Services inherit from `AbstractService<State, Action>` for consistency
- UI components follow WhimScene pattern for map-based screens
- All state mutations happen in pure reducer functions
- Side effects isolated to Feedback components