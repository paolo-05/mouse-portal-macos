// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MousePortal",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MousePortal", targets: ["MousePortal"]),
        .library(name: "MousePortalCore", targets: ["MousePortalCore"])
    ],
    targets: [
        .target(name: "MousePortalCore"),
        .executableTarget(
            name: "MousePortal",
            dependencies: ["MousePortalCore"]
        ),
        .testTarget(
            name: "MousePortalCoreTests",
            dependencies: ["MousePortalCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)
