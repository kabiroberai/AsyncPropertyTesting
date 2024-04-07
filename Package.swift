// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AsyncPropertyTesting",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "AsyncPropertyTesting",
            targets: ["AsyncPropertyTesting"]
        ),
    ],
    targets: [
        .target(
            name: "AsyncPropertyTesting"
        ),
        .testTarget(
            name: "AsyncPropertyTestingTests",
            dependencies: ["AsyncPropertyTesting"]
        ),
    ]
)
