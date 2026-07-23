// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WireGuardKit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(name: "WireGuardKit", targets: ["WireGuardKit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "WireGuardKit",
            dependencies: ["WireGuardKitGo", "WireGuardKitC"]
        ),
        .target(
            name: "WireGuardKitC",
            dependencies: [],
            publicHeadersPath: "."
        ),
        // Precompiled Go bridge. Regenerate with `make -C Sources/WireGuardKitGo`
        // (requires a Go toolchain) and commit the resulting xcframework;
        // consumers of this package do not need Go installed to build.
        .binaryTarget(
            name: "WireGuardKitGo",
            path: "Sources/WireGuardKitGo/WireGuardKitGo.xcframework"
        )
    ]
)
