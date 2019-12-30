# Installing WireGuard tunnels using Configuration Profiles

WireGuard configurations can be installed using Configuration Profiles
through .mobileconfig files.

### Top-level payload entries

A .mobileconfig file is a plist file in XML format. The top-level XML item is a top-level payload dictionary (dict). This payload dictionary should contain the following keys:

  - `PayloadDisplayName` (string): The name of the configuration profile, visible when installing the profile

  - `PayloadType` (string): Should be `Configuration`

  - `PayloadVersion` (integer): Should be `1`

  - `PayloadIdentifier` (string): A reverse-DNS style unique identifier for the profile file.
    If you install another .mobileconfig file with the same identifier, the new one
    overwrites the old one.

  - `PayloadUUID` (string): A randomly generated UUID for this payload

  - `PayloadContent` (array): Should contain an array of payload dictionaries.
    Each of these payload dictionaries can represent a WireGuard tunnel
    configuration.

Here's an example .mobileconfig with the above fields filled in:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PayloadDisplayName</key>
	<string>WireGuard Demo Configuration Profile</string>
	<key>PayloadType</key>
	<string>Configuration</string>
	<key>PayloadVersion</key>
	<integer>1</integer>
	<key>PayloadIdentifier</key>
	<string>com.your-org.wireguard.FCC9BF80-C540-44C1-B243-521FDD1B2905</string>
	<key>PayloadUUID</key>
	<string>F346AAF4-53A2-4FA1-ACA3-EEE74DBED029</string>
	<key>PayloadContent</key>
	<array>
        <!-- An array of WireGuard configuration payload dictionaries -->
	</array>
</dict>
</plist>
```

### WireGuard payload entries

Each WireGuard configuration payload dictionary should contain the following
keys:

  - `PayloadDisplayName` (string): Should be `VPN`

  - `PayloadType` (string): Should be `com.apple.vpn.managed`

  - `PayloadVersion` (integer): Should be `1`

  - `PayloadIdentifier` (string): A reverse-DNS style unique identifier for the WireGuard configuration profile.

  - `PayloadUUID` (string): A randomly generated UUID for this payload

  - `UserDefinedName` (string): The name of the WireGuard tunnel.
    This name shall be used to represent the tunnel in the WireGuard app, and in the System UI for VPNs (Settings > VPN on iOS, System Preferences > Network on macOS).

  - `VPNType` (string): Should be `VPN`

  - `VPNSubType` (string): Should be set as the bundle identifier of the WireGuard app.

     - iOS: `com.wireguard.ios`
     - macOS: `com.wireguard.macos`

  - `VendorConfig` (dict): Should be a dictionary with the following key:

    - `WgQuickConfig` (string): Should be a WireGuard configuration in [wg-quick(8)] / [wg(8)] format.
      The keys 'FwMark', 'Table', 'PreUp', 'PostUp', 'PreDown', 'PostDown' and 'SaveConfig' are not supported.

  - `VPN` (dict): Should be a dictionary with the following keys:

    - `RemoteAddress` (string): A non-empty string.
      This string is displayed as the server name in the System UI for
      VPNs (Settings > VPN on iOS, System Preferences > Network on macOS).

    - `AuthenticationMethod` (string): Should be `Password`

Here's an example WireGuard configuration payload dictionary:

```xml
<!-- A WireGuard configuration payload dictionary -->
<dict>
    <key>PayloadDisplayName</key>
    <string>VPN</string>
    <key>PayloadType</key>
    <string>com.apple.vpn.managed</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadIdentifier</key>
    <string>com.your-org.wireguard.demo-profile-1.demo-tunnel</string>
    <key>PayloadUUID</key>
    <string>44CDFE9F-4DC7-472A-956F-61C68055117C</string>
    <key>UserDefinedName</key>
    <string>Demo from MobileConfig file</string>
    <key>VPNType</key>
    <string>VPN</string>
    <key>VPNSubType</key>
    <string>com.wireguard.ios</string>
    <key>VendorConfig</key>
    <dict>
        <key>WgQuickConfig</key>
        <string>
        [Interface]
        PrivateKey = mInDaw06K0NgfULRObHJjkWD3ahUC8XC1tVjIf6W+Vo=
        Address = 10.10.1.0/24
        DNS = 1.1.1.1, 1.0.0.1

        [Peer]
        PublicKey = JRI8Xc0zKP9kXk8qP84NdUQA04h6DLfFbwJn4g+/PFs=
        Endpoint = demo.wireguard.com:12912
        AllowedIPs = 0.0.0.0/0
        </string>
    </dict>
    <key>VPN</key>
     <dict>
        <key>RemoteAddress</key>
        <string>demo.wireguard.com:12912</string>
        <key>AuthenticationMethod</key>
        <string>Password</string>
    </dict>
</dict>
```

### Caveats

Configurations added via .mobileconfig will not be migrated into keychain until the WireGuard application is opened once.

[wg-quick(8)]: https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8
[wg(8)]: https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8
