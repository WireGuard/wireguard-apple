# WireGuardKit and Swift Package Manager

`WireGuardKit` is delivered as a Swift package, but **SwiftPM does not compile Go**. The tunnel still needs the static library produced from `Sources/WireGuardKitGo` (`libwg-go.a`, linked as `-lwg-go`).

So “SPM only” for the **dependency** is normal; “no `libwg-go` step at all” is not supported for this codebase.

## Option A — Recommended (matches upstream wireguard-apple)

1. Add this package to your app in Xcode (**File → Add Package Dependencies…**).
2. Create an **External Build System** target that runs **`/usr/bin/make`** with **Directory** set to the **checkout** of `WireGuardKitGo` inside Derived Data, for example:
   ```text
   ${BUILD_DIR%Build/*}SourcePackages/checkouts/<your-checkout-folder-name>/Sources/WireGuardKitGo
   ```
   The folder name after `checkouts/` must match your package identity (see **Package.resolved**, e.g. `wireguard-apple-sf-vpn`). **Do not** hardcode a path like `/Library/wireguard-apple-SF-VPN/...` — that only works on one machine and drifts from what SwiftPM actually compiles.

3. In the **External Build System** target **Build Settings** (for an **iOS** packet-tunnel extension):
   - **SDKROOT** = `iphoneos`
   - **PLATFORM_NAME** = `iphoneos` (so `make` builds `GOOS=ios`, not the Makefile default `macosx`)
   - **ARCHS** = `arm64` for device-only builds (adjust if you need simulator slices)

   Without **iphoneos**, the Makefile defaults to **macOS** artifacts, which do not match an iOS Network Extension.

4. Add that external target as a **dependency** of your **Network Extension** target (so `make` runs before link).
5. Link **WireGuardKit** to the app and extension as in the main [README](../README.md#wireguardkit-integration-third-party-apps).

After each `swift package resolve` / checkout path change, fix the **Directory** path if the folder name differs.

## Option B — Prebuilt binary (true “no make on every machine”)

1. On a machine with Go + Xcode, run `make` in `Sources/WireGuardKitGo` for each slice you need and package an **XCFramework** (or vendored `libwg-go.a` per platform).
2. In your **app** project (not necessarily in this repo), add a **binary Swift package** or copy the framework into the extension target and adjust **Library Search Paths** / linker flags so `-lwg-go` resolves.

Maintaining that binary is on you; this fork does not ship a downloadable XCFramework in-tree.

## Checking that the right library is linked

- After integrating, the extension should log **`WireGuardKitGo build marker OK: tun-read-v4`** (see `WireGuardAdapter`).  
- If you still see **`Received packet with unknown IP version`**, the linked `libwg-go.a` is **not** from this fork’s patched Go sources — rebuild the bridge and ensure the extension does not pick up an older `.a` from another path.

## Verify from the command line (this repo)

```bash
cd Sources/WireGuardKitGo
make clean && make verify-no-legacy-tun-log verify-build-marker-present
```

Use the produced `out/libwg-go.a` only if your extension’s linker is configured to find it (Option A or B above).
