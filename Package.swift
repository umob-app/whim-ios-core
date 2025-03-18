// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "whim-ios-core",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "WhimCore",
            targets: ["WhimCore"]
        ),
    ],
    dependencies: [
        // Sources
        .package(url: "https://github.com/ReactiveX/RxSwift.git", exact: "6.5.0"),
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.1.0")),
        // Tests
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "9.0.0")),
        .package(url: "https://github.com/stanfy/SwiftyMock.git", branch: "spm"),
        .package(url: "https://github.com/maasglobal/whim-ios-random.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "WhimCore",
            dependencies: [
                "RxSwift",
                .product(name: "RxCocoa", package: "RxSwift"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]
        ),
        .testTarget(
            name: "WhimCoreTests",
            dependencies: [
                "WhimCore",
                "Quick",
                "Nimble",
                "SwiftyMock",
                .product(name: "WhimRandom", package: "whim-ios-random"),
                .product(name: "RxTest", package: "RxSwift"),
                .product(name: "RxBlocking", package: "RxSwift"),
            ]
        ),
    ]
)
