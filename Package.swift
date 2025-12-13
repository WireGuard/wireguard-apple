// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let url = "https://github.com/ridgelineinternational/wireguard-apple-xcframework/releases/download/0.0.7/WireGuardGoFoundation.xcframework.zip"
let checksum = "9cf2b8e63e92bcb21ff0c453c10afa1977992f1aea38e28b9bf5be5804beab0e"

let package = Package(
    name: "WireGuardKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "WireGuardKit", targets: ["WireGuardKit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "WireGuardKit",
            dependencies: ["WireGuardGoFoundation", "WireGuardKitC"]
        ),
        .target(
            name: "WireGuardKitC",
            dependencies: [],
            publicHeadersPath: "."
        ),
        .binaryTarget(name: "WireGuardGoFoundation", url: url, checksum: checksum)
    ]
)
