# [WireGuard](https://www.wireguard.com/) for iOS and macOS

This project contains an application for iOS and for macOS, as well as many components shared between the two of them. You may toggle between the two platforms by selecting the target from within Xcode.

## Building

- Clone this repo:

```
$ git clone https://git.zx2c4.com/wireguard-apple
$ cd wireguard-apple
```

- Rename and populate developer team ID file:

```
$ cp Sources/WireGuardApp/Config/Developer.xcconfig.template Sources/WireGuardApp/Config/Developer.xcconfig
$ vim Sources/WireGuardApp/Config/Developer.xcconfig
```

- Install swiftlint and go 1.19:

```
$ brew install swiftlint go
```

- Open project in Xcode:

```
$ open WireGuard.xcodeproj
```

- Flip switches, press buttons, and make whirling noises until Xcode builds it.

## WireGuardKit integration (third-party apps)

Use this when you embed **WireGuardKit** in **your own** iOS or macOS app (not when building the WireGuard app from this repo).

**Overview:** Add the package in Xcode, then ensure the **Go bridge** is linked. `WireGuardKit` asks the linker for **`-lwg-go`** (SwiftPM does **not** compile Go). The usual way is to run `make` in `WireGuardKitGo` via an **External Build System** target; the product is typically **`libwg-go.a`**, but your app does **not** need a file literally named that in the project — any setup where **`-lwg-go` resolves** (search paths, XCFramework, CI artifact, etc.) is fine. Details: [Documentation/WireGuardKit-SPM.md](Documentation/WireGuardKit-SPM.md).

**Prerequisites on the machine that builds the extension:** [Go](https://go.dev/dl/) (1.19+ recommended) and Xcode with the correct command-line tools.

### Same flow as upstream (quick map)

This is the **same** recipe [upstream wireguard-apple](https://git.zx2c4.com/wireguard-apple) documents: **SPM + External Build System + extension depends on `make` + link `WireGuardKit`**. The numbered steps below are that recipe, with extra notes for **this fork** (checkout folder name, `PLATFORM_NAME`, etc.).

| Upstream step | Still here |
|---------------|------------|
| Add Swift package | §1 (upstream URL or **this fork’s** Git URL) |
| New **External Build System** target, `make`, Directory under `SourcePackages/checkouts/.../WireGuardKitGo` | §2 |
| **SDKROOT** `iphoneos` or `macosx` | §2 (plus **PLATFORM_NAME** / **ARCHS** for iOS — avoids wrong `libwg-go.a`) |
| Extension **Dependencies** → bridge target; **Link** `WireGuardKit` | §3 |
| App links `WireGuardKit` | §4 |
| iOS **Bitcode** off | §5 |

### 1. Add the Swift package

In your app project: **File → Add Package Dependencies…** and add either:

- Upstream: `https://git.zx2c4.com/wireguard-apple`, or  
- This fork / a mirror: your **Git URL** or **Add Local…** pointing at a clone of this repository.

### 2. Build the `wireguard-go-bridge` (`WireGuardKitGo`)

`WireGuardKit` links **`-lwg-go`**. The Makefile produces **`libwg-go.a`** into the build products directory; Xcode does not require you to drag that filename into the project if the linker already finds `libwg-go` elsewhere. The common approach is an **External Build System** target so `make` runs before the Network Extension links.

- **File → New → Target → Other → External Build System.**
- **Product name:** e.g. `WireGuardGoBridgeiOS` or `WireGuardGoBridgeMac`, matching the platform you build for.
- **Build tool:** `/usr/bin/make` (default).
- **Info → Directory** (External Build Tool Configuration): point at **`WireGuardKitGo`** inside the **SwiftPM checkout** under Derived Data. The checkout folder name is **not** always `wireguard-apple` — use the actual directory name Xcode created (repo name or package identity):

  ```
  ${BUILD_DIR%Build/*}SourcePackages/checkouts/<YOUR_CHECKOUT_FOLDER_NAME>/Sources/WireGuardKitGo
  ```

  Example: SwiftPM often uses the package **identity** from **Package.resolved** (e.g. `wireguard-apple-sf-vpn`), so the path may be  
  `.../checkouts/wireguard-apple-sf-vpn/Sources/WireGuardKitGo`. **Avoid** a fixed path such as `/Library/wireguard-apple-SF-VPN/...` — it breaks on other Macs/CI and can diverge from the checkout Xcode uses for Swift.

- **Build Settings** for the External Build target:
  - **SDKROOT:** `iphoneos` (iOS extension) or `macosx` (Mac).
  - **PLATFORM_NAME:** set to the same (`iphoneos` or `macosx`). The `Makefile` defaults to **macosx**; if you omit this on an iOS project, `make` can produce the **wrong** `libwg-go.a` for your extension.
  - **ARCHS:** e.g. `arm64` for iOS device; match what you ship.

### 3. Network Extension target

Open your **Network Extension** target (e.g. **Packet Tunnel Provider**):

- **Build Phases → Dependencies:** add **`WireGuardGoBridge…`** (the external target from step 2) so it builds before the extension.
- **Build Phases → Link Binary With Libraries:** add **`WireGuardKit`**.

Your extension still needs the usual **Network Extension** entitlements (e.g. **Packet Tunnel Provider**) and a **`NEPacketTunnelProvider`** subclass that uses **`WireGuardAdapter`** (see `Sources/WireGuardNetworkExtension/PacketTunnelProvider.swift` in this repo as a reference).

### 4. Main app target

- **Build Phases → Link Binary With Libraries:** add **`WireGuardKit`** (if your app code imports it).

### 5. iOS only

- **Build Settings → Enable Bitcode:** **No** for the app (and extension if applicable).

### Both platforms

If you ship **iOS and macOS**, repeat steps 2–3 **per platform** (separate external build targets and SDKROOT values).

More detail, troubleshooting, and a prebuilt-library option: **[Documentation/WireGuardKit-SPM.md](Documentation/WireGuardKit-SPM.md)**.

## MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
