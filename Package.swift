// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NavigationCoordinator",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "NavigationCoordinator",
            targets: ["NavigationCoordinator"]
        ),
    ],
    targets: [
        .target(name: "NavigationCoordinator"),
        .testTarget(
            name: "NavigationCoordinatorTests",
            dependencies: ["NavigationCoordinator"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
