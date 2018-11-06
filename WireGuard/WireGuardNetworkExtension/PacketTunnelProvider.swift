// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import NetworkExtension
import os.log

enum PacketTunnelProviderError: Error {
    case invalidOptions
    case couldNotStartWireGuard
    case coultNotSetNetworkSettings
}

/// A packet tunnel provider object.
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: Properties

    private var wgHandle: Int32?

    // MARK: NEPacketTunnelProvider

    /// Begin the process of establishing the tunnel.
    override func startTunnel(options: [String: NSObject]?,
                              completionHandler startTunnelCompletionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel", log: OSLog.default, type: .info)

        guard let options = options else {
            os_log("Starting tunnel failed: No options passed. Possible connection request from preferences", log: OSLog.default, type: .error)
            // displayMessage is deprecated API
            displayMessage("Please use the WireGuard app to start WireGuard tunnels") { (_) in
                startTunnelCompletionHandler(PacketTunnelProviderError.invalidOptions)
            }
            return
        }

        guard let interfaceName = options[.interfaceName] as? String,
            let wireguardSettings = options[.wireguardSettings] as? String,
            let remoteAddress = options[.remoteAddress] as? String,
            let dnsServers = options[.dnsServers] as? [String],
            let mtu = options[.mtu] as? NSNumber,

            // IPv4 settings
            let ipv4Addresses = options[.ipv4Addresses] as? [String],
            let ipv4SubnetMasks = options[.ipv4SubnetMasks] as? [String],
            let ipv4IncludedRouteAddresses = options[.ipv4IncludedRouteAddresses] as? [String],
            let ipv4IncludedRouteSubnetMasks = options[.ipv4IncludedRouteSubnetMasks] as? [String],
            let ipv4ExcludedRouteAddresses = options[.ipv4ExcludedRouteAddresses] as? [String],
            let ipv4ExcludedRouteSubnetMasks = options[.ipv4ExcludedRouteSubnetMasks] as? [String],

            // IPv6 settings
            let ipv6Addresses = options[.ipv6Addresses] as? [String],
            let ipv6NetworkPrefixLengths = options[.ipv6NetworkPrefixLengths] as? [NSNumber],
            let ipv6IncludedRouteAddresses = options[.ipv6IncludedRouteAddresses] as? [String],
            let ipv6IncludedRouteNetworkPrefixLengths = options[.ipv6IncludedRouteNetworkPrefixLengths] as? [NSNumber],
            let ipv6ExcludedRouteAddresses = options[.ipv6ExcludedRouteAddresses] as? [String],
            let ipv6ExcludedRouteNetworkPrefixLengths = options[.ipv6ExcludedRouteNetworkPrefixLengths] as? [NSNumber]

            else {
                os_log("Starting tunnel failed: Invalid options passed", log: OSLog.default, type: .error)
                startTunnelCompletionHandler(PacketTunnelProviderError.invalidOptions)
                return
        }

        configureLogger()

        let fd = packetFlow.value(forKeyPath: "socket.fileDescriptor") as! Int32
        if fd < 0 {
            os_log("Starting tunnel failed: Could not determine file descriptor", log: OSLog.default, type: .error)
            startTunnelCompletionHandler(PacketTunnelProviderError.couldNotStartWireGuard)
            return
        }
        let handle = connect(interfaceName: interfaceName, settings: wireguardSettings, fd: fd)

        if handle < 0 {
            os_log("Starting tunnel failed: Could not start WireGuard", log: OSLog.default, type: .error)
            startTunnelCompletionHandler(PacketTunnelProviderError.couldNotStartWireGuard)
            return
        }

        wgHandle = handle

        // Network settings
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: remoteAddress)

        // IPv4 settings
        let ipv4Settings = NEIPv4Settings(addresses: ipv4Addresses, subnetMasks: ipv4SubnetMasks)
        assert(ipv4IncludedRouteAddresses.count == ipv4IncludedRouteSubnetMasks.count)
        ipv4Settings.includedRoutes = zip(ipv4IncludedRouteAddresses, ipv4IncludedRouteSubnetMasks).map {
            NEIPv4Route(destinationAddress: $0.0, subnetMask: $0.1)
        }
        assert(ipv4ExcludedRouteAddresses.count == ipv4ExcludedRouteSubnetMasks.count)
        ipv4Settings.excludedRoutes = zip(ipv4ExcludedRouteAddresses, ipv4ExcludedRouteSubnetMasks).map {
            NEIPv4Route(destinationAddress: $0.0, subnetMask: $0.1)
        }
        networkSettings.ipv4Settings = ipv4Settings

        // IPv6 settings

        /* Big fat ugly hack for broken iOS networking stack: the smallest prefix that will have
         * any effect on iOS is a /120, so we clamp everything above to /120. This is potentially
         * very bad, if various network parameters were actually relying on that subnet being
         * intentionally small. TODO: talk about this with upstream iOS devs.
         */
        let ipv6Settings = NEIPv6Settings(addresses: ipv6Addresses, networkPrefixLengths: ipv6NetworkPrefixLengths.map { NSNumber(value: min(120, $0.intValue)) })
        assert(ipv6IncludedRouteAddresses.count == ipv6IncludedRouteNetworkPrefixLengths.count)
        ipv6Settings.includedRoutes = zip(ipv6IncludedRouteAddresses, ipv6IncludedRouteNetworkPrefixLengths).map {
            NEIPv6Route(destinationAddress: $0.0, networkPrefixLength: $0.1)
        }
        assert(ipv6ExcludedRouteAddresses.count == ipv6ExcludedRouteNetworkPrefixLengths.count)
        ipv6Settings.excludedRoutes = zip(ipv6ExcludedRouteAddresses, ipv6ExcludedRouteNetworkPrefixLengths).map {
            NEIPv6Route(destinationAddress: $0.0, networkPrefixLength: $0.1)
        }
        networkSettings.ipv6Settings = ipv6Settings

        // DNS
        networkSettings.dnsSettings = NEDNSSettings(servers: dnsServers)

        // MTU
        if (mtu == 0) {
            // 0 imples automatic MTU, where we set overhead as 80 bytes, which is the worst case for WireGuard
            networkSettings.tunnelOverheadBytes = 80
        } else {
            networkSettings.mtu = mtu
        }

        setTunnelNetworkSettings(networkSettings) { (error) in
            if let error = error {
                os_log("Starting tunnel failed: Error setting network settings: %s", log: OSLog.default, type: .error, error.localizedDescription)
                startTunnelCompletionHandler(PacketTunnelProviderError.coultNotSetNetworkSettings)
            } else {
                startTunnelCompletionHandler(nil /* No errors */)
            }
        }
    }

    /// Begin the process of stopping the tunnel.
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping tunnel", log: OSLog.default, type: .info)
        if let handle = wgHandle {
            wgTurnOff(handle)
        }
        completionHandler()
    }

    private func configureLogger() {
        wgSetLogger { (level, msgCStr) in
            let logType: OSLogType
            switch level {
            case 0:
                logType = .debug
            case 1:
                logType = .info
            case 2:
                logType = .error
            default:
                logType = .default
            }
            let msg = (msgCStr != nil) ? String(cString: msgCStr!) : ""
            os_log("%{public}s", log: OSLog.default, type: logType, msg)
        }
    }

    private func connect(interfaceName: String, settings: String, fd: Int32) -> Int32 { // swiftlint:disable:this cyclomatic_complexity
        return withStringsAsGoStrings(interfaceName, settings) { (nameGoStr, settingsGoStr) -> Int32 in
            return wgTurnOn(nameGoStr, settingsGoStr, fd)
        }
    }
}

private func withStringsAsGoStrings<R>(_ str1: String, _ str2: String, closure: (gostring_t, gostring_t) -> R) -> R {
    return str1.withCString { (s1cStr) -> R in
        let gstr1 = gostring_t(p: s1cStr, n: str1.utf8.count)
        return str2.withCString { (s2cStr) -> R in
            let gstr2 = gostring_t(p: s2cStr, n: str2.utf8.count)
            return closure(gstr1, gstr2)
        }
    }
}
