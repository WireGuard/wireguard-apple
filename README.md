# WireGuardKit - Swift Package for iOS and macOS

A Swift Package Manager library providing [WireGuard](https://www.wireguard.com/) VPN functionality for iOS and macOS applications. This package wraps the official WireGuard-Go implementation in an easy-to-use Swift interface with prebuilt XCFramework binaries.

## Overview

This project consists of two main components:

1. **Go Foundation Layer** (`WireGuardGoFoundationSource/`) - A thin Go shim around the official WireGuard implementation, compiled into native XCFramework binaries for iOS, iOS Simulator, and macOS
2. **Swift Package** - Swift wrapper providing a clean API for WireGuard functionality

The package uses **prebuilt binaries** distributed via GitHub Releases, so consumers don't need Go installed or need to compile anything themselves.

## Platform Support

- **iOS**: 16.0+
- **macOS**: 13.0+
- **iOS Simulator**: arm64, x86_64

## Installation

### Swift Package Manager

Add this package to your Xcode project or `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ridgelineinternational/wireguard-apple-xcframework.git", from: "0.0.5")
]
```

Then add `WireGuardKit` as a dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["WireGuardKit"]
)
```

## Project Structure

### Library Components (Active)

- **`Sources/WireGuardKit/`** - Swift library code providing the main WireGuardKit API (this is what you import in your projects)
- **`Sources/WireGuardKitC/`** - C bridge layer connecting Swift to Go
- **`Sources/Shared/`** - Shared utilities (logging, models, keychain helpers)
- **`WireGuardGoFoundationSource/`** - Go shim + build system for the native XCFramework

### Build Infrastructure

- **`Package.swift`** - Swift Package Manager manifest
- **`.github/workflows/`** - GitHub Actions for building and releasing
- **`WireGuardGoFoundationSource/Makefile`** - Build system for compiling Go code into XCFramework

### Legacy Code

- **`Legacy Example Code/`** - Contains the original WireGuard iOS/macOS applications, network extension implementations, and related tooling. Preserved for reference but not used by the library.

## Building the XCFramework

> **Note**: Most users don't need to build anything - just add the package as a dependency and Swift Package Manager will download the prebuilt XCFramework.

If you need to build from source (for security auditing or contributing):

### Via GitHub Actions (Recommended)

This is the easiest way to create a trusted build:

1. Fork this repository
2. Go to **Actions** in your fork
3. Select the **"Go Dependency Wrapper"** workflow
4. Click **"Run workflow"** on the right side
5. Configure the build:
   - **Update go dependencies**: Check this to update to the latest WireGuard-Go version
   - **Patch only**: Check this to only update patch versions (safer)
   - **Tag**: Provide a version tag (e.g., `0.0.6`)
6. Click **"Run Workflow"**

The workflow will:
- Build the XCFramework for all platforms
- Create a GitHub release with your tag
- Upload the built XCFramework
- Automatically update `Package.swift` with the new URL and checksum

Your fork will now have a release you can reference in your projects.

### Building Locally

For local development or if you want to inspect every step:

1. **Prerequisites**:
   ```bash
   brew install go
   ```

2. **Clone and navigate**:
   ```bash
   git clone https://github.com/ridgelineinternational/wireguard-apple-xcframework.git
   cd wireguard-apple-xcframework/WireGuardGoFoundationSource
   ```

3. **Build the XCFramework**:
   ```bash
   make clean
   make build-xcframework
   ```

4. **Create release zip**:
   ```bash
   zip -ry WireGuardGoFoundation.xcframework.zip WireGuardGoFoundation.xcframework
   ```

For detailed steps, see `.github/workflows/build-go-dependency-wrapper.yml`.

## Updating WireGuard Dependencies

The core WireGuard functionality comes from the official `golang.zx2c4.com/wireguard` Go package. To update to the latest version:

1. Navigate to the Go source directory:
   ```bash
   cd WireGuardGoFoundationSource
   ```

2. Update dependencies:
   ```bash
   # Update all dependencies to latest versions
   go get -u ./...
   
   # OR update only patch versions (safer)
   go get -u=patch ./...
   ```

3. Clean up:
   ```bash
   go mod tidy
   ```

4. Test the build:
   ```bash
   make clean
   make build-xcframework
   ```

5. Create a new release (via GitHub Actions or manually)

**Note**: The GitHub Actions workflow includes an option to automatically run `go get -u` during the build process.

## Security Note

This repository distributes **prebuilt binaries** via GitHub Releases. If you have security requirements that prevent using third-party binaries:

1. Fork this repository
2. Audit the code (everything is transparent and auditable)
3. Run the GitHub Actions workflow in your fork to create your own trusted build
4. Reference your fork's releases in your projects

The entire build process is reproducible and automated via GitHub Actions.

## License

See [LICENSE.md](LICENSE.md) and [COPYING](COPYING) for details.

## Related Projects

- [Official WireGuard Go Implementation](https://git.zx2c4.com/wireguard-go/)
- [Original WireGuard Apple Apps](https://git.zx2c4.com/wireguard-apple/)
