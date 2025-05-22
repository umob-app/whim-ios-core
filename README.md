# WhimCore
<!-- [![codecov](https://codecov.io/gh/umob-app/whim-ios-core/branch/main/graph/badge.svg?token=9nsaxD0896)](https://codecov.io/gh/umob-app/whim-ios-core) -->

Core utilities and architecture components for iOS applications.

- Whim Architecture & UI Tools
- User Flow Navigation
- Abstract Shared Map
- Geo Hash & Caching + Proximity Hash
- Sliding Bottom Panel
- Testing Tools
- Xcode Templates

## Documentation

- [Architecture](Sources/WhimCore/Documentation.docc/Architecture.md)
- [UI](Sources/WhimCore/Documentation.docc/UI.md)
- [Navigation](Sources/WhimCore/Documentation.docc/Navigation.md)
- [Map](Sources/WhimCore/Documentation.docc/Map.md)
- [GeoHash-Caching](Sources/WhimCore/Documentation.docc/GeoHash-Caching.md)
- [Bottom-Panel](Sources/WhimCore/Documentation.docc/Bottom-Panel.md)
- [Utils](Sources/WhimCore/Documentation.docc/Utils.md)
- [WhimCoreTest](Sources/WhimCoreTest/Documentation.docc/Documentation.md)

Documentation is organized in the [Swift DocC](https://www.swift.org/documentation/docc) format.
You can build it from command line and view as a website, or it can be built from Xcode.

#### To generate it from the Xcode and view it along with the rest of the documentation opened in Xcode perform next steps:
- open the WhimCore package (`open Package.swift`)
- go to Product > Build Documentation (`⌃ ⇧ ⌘ D`)
> note: once you close the package, documentation closes too.

#### To generate DocC from the command line and preview it in the browser execute the following scripts:
```bash
scripts/docs
open "http://localhost:8080/documentation"
```
It will generate docs into a temporary `.docs` directory and run a local server on 8080 port. It's all handled by the `swift package` tool.

## Demo Project

Run the `WhimCoreDemo/WhimCoreDemo.xcodeproj` project in your Xcode.
No additional setup is needed as it's using SPM for extra dependencies.
WhimCoreDemo is intended mostly for exploration and showcasing the tools.

## Requirements

- Xcode 15+
- Swift 5.10+

## Templates

Xcode Templates for creating screens and services can be found in `Templates` directory.
Execute `scripts/templates` script to install them, or add them manually into the `~/Library/Developer/Xcode/Templates/File Templates/` direcory.

## Contributors
<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<table>
  <tr>
    <td align="center"><a href="https://github.com/a-voronov"><img src="https://avatars.githubusercontent.com/u/11717236?v=4" width="100px;" alt=""/><br /><sub><b>Oleksandr Voronov</b></sub></a><br /><a href="https://github.com/umob-app/whim-ios-core/commits?author=a-voronov" title="Idea & Implementation">💡💻</a></td>
    <td align="center"><a href="https://github.com/kanh296"><img src="https://avatars.githubusercontent.com/u/93093745?v=4" width="100px;" alt=""/><br /><sub><b>Anh Hoang</b></sub></a><br /><a href="https://github.com/umob-app/whim-ios-core/commits?author=kanh296" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/volatilegg"><img src="https://avatars.githubusercontent.com/u/3374348?v=4" width="100px;" alt=""/><br /><sub><b>Duc Do</b></sub></a><br /><a href="https://github.com/umob-app/whim-ios-core/commits?author=volatilegg" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/RubenEsposito"><img src="https://avatars.githubusercontent.com/u/780945?v=4" width="100px;" alt=""/><br /><sub><b>Ruben Marin</b></sub></a><br /><a href="https://github.com/umob-app/whim-ios-core/commits?author=RubenEsposito" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/zyrikin"><img src="https://avatars.githubusercontent.com/u/3982699?v=4" width="100px;" alt=""/><br /><sub><b>Nik Zakirin</b></sub></a><br /><a href="https://github.com/umob-app/whim-ios-core/commits?author=zyrikin" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/mario2r"><img src="https://avatars.githubusercontent.com/u/11093933?v=4" width="100px;" alt=""/><br /><sub><b>Mario Romero</b></sub></a><br /><a href="https://github.com/umob-app/whim-ios-core/commits?author=mario2r" title="Code">💻</a></td>
  </tr>
</table>


## License

MIT License
