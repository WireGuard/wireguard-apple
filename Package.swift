// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WireGuardKit",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v12)
    ],
    products: [
        .library(name: "WireGuardKit", targets: ["WireGuardKit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "WireGuardKit",
            dependencies: ["libwg-go", "WireGuardKitCTarget"],
            path: "WireGuardKit/Sources/WireGuardKit"
        ),
        .target(
            name: "WireGuardKitCTarget",
            dependencies: [],
            path: "WireGuardKit/Sources/WireGuardKitCTarget"
        ),
        .target(
            name: "libwg-go",
            dependencies: [],
            path: "WireGuardKit/Sources/libwg-go",
            linkerSettings: [.linkedLibrary("wg-go")]
        )
    ]
)
