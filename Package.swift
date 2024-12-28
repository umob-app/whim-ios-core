// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "whim-ios-core",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "WhimCore",
            targets: ["WhimCore"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/ReactiveX/RxSwift.git", exact: "6.5.0"),
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "9.0.0")),
        .package(url: "https://github.com/maasglobal/whim-ios-utils.git", branch: "main"),
        .package(url: "https://github.com/maasglobal/whim-ios-random.git", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "WhimCore",
            dependencies: [
                .product(name: "WhimRandom", package: "whim-ios-random"),
                .product(name: "RxCocoa", package: "RxSwift"),
                "RxSwift",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WhimCoreTests",
            dependencies: [
                "WhimCore",
                "Quick",
                "Nimble",
                .product(name: "WhimRandom", package: "whim-ios-random"),
                .product(name: "RxTest", package: "RxSwift"),
                .product(name: "RxBlocking", package: "RxSwift"),
            ]),
    ]
)
