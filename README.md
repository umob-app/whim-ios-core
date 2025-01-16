# WhimCore
[![codecov](https://codecov.io/gh/maasglobal/whim-ios-core/branch/main/graph/badge.svg?token=9nsaxD0896)](https://codecov.io/gh/maasglobal/whim-ios-core)

Core utilities and architecture components for iOS applications.

- Whim Architecture Utils
- Home Flow Navigation
- Home Abstract Shared Map
- Home Bottom Panel

## Requirements

- Xcode 15+
- Swift 5.10+
- Cocoapods 1.11+

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

Example project is intended to be used in order to speed up UI components development, 
because main project takes ~70-80sec to recompile after every minor change.
There's everything that might be potentially needed to test your code independently from the main project. 
After you're done, move your code into main project and bind it to business logic layer.
You can test your code and create different scenarios right in `AppDelegate`.

## Installation

Setup Ruby environment and pod installation for example project.

```sh
cd Example
bundle install
bundle exec pod install
```

## Playground

There's also a Playground, so you can play around with WhimCore. In order to start using it:

 1. Open `Example/WhimCore.xcworkspace`.
 1. Build `WhimCore-Example` scheme.
 1. Finally open the `Example/WhimCore.playground`.
 1. Choose `View > Show Debug Area`.
 
 ## Note 
 
 Common files are shared between Playground and Example project to reduce code duplication, and require public access to be available in Playground.

## Templates

Xcode Templates for creating V2 scenes and services can be found in `WhimCore/Templates` directory. 
Execute `./WhimCore/Templates/install` script to install them, or add them manually into the `~/Library/Developer/Xcode/Templates/File Templates/` direcory.

## Contributors
## Contributors
<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<table>
  <tr>
    <td align="center"><a href="https://github.com/a-voronov"><img src="https://avatars.githubusercontent.com/u/11717236?v=4" width="100px;" alt=""/><br /><sub><b>Oleksandr Voronov</b></sub></a><br /><a href="https://github.com/maasglobal/whim-ios-core/commits?author=a-voronov" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/kanh296"><img src="https://avatars.githubusercontent.com/u/93093745?v=4" width="100px;" alt=""/><br /><sub><b>Anh Hoang</b></sub></a><br /><a href="https://github.com/maasglobal/whim-ios-core/commits?author=kanh296" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/volatilegg"><img src="https://avatars.githubusercontent.com/u/3374348?v=4" width="100px;" alt=""/><br /><sub><b>Duc Do</b></sub></a><br /><a href="https://github.com/maasglobal/whim-ios-core/commits?author=volatilegg" title="Code">💻</a></td>
  </tr>  
</table>


## License

MIT License
