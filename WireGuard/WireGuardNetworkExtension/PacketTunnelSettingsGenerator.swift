// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import Network
import NetworkExtension

class PacketTunnelSettingsGenerator {

    let tunnelConfiguration: TunnelConfiguration
    let resolvedEndpoints: [Endpoint?]

    init(tunnelConfiguration: TunnelConfiguration, resolvedEndpoints: [Endpoint?]) {
        self.tunnelConfiguration = tunnelConfiguration
        self.resolvedEndpoints = resolvedEndpoints
    }

    func generateWireGuardSettings() -> String {
        var wgSettings = ""
        let privateKey = tunnelConfiguration.interface.privateKey.hexEncodedString()
        wgSettings.append("private_key=\(privateKey)\n")
        if let listenPort = tunnelConfiguration.interface.listenPort {
            wgSettings.append("listen_port=\(listenPort)\n")
        }
        if (tunnelConfiguration.peers.count > 0) {
            wgSettings.append("replace_peers=true\n")
        }
        assert(tunnelConfiguration.peers.count == resolvedEndpoints.count)
        for (i, peer) in tunnelConfiguration.peers.enumerated() {
            wgSettings.append("public_key=\(peer.publicKey.hexEncodedString())\n")
            if let preSharedKey = peer.preSharedKey {
                wgSettings.append("preshared_key=\(preSharedKey.hexEncodedString())\n")
            }
            if let endpoint = resolvedEndpoints[i] {
                if case .name(_, _) = endpoint.host { assert(false, "Endpoint is not resolved") }
                wgSettings.append("endpoint=\(endpoint.stringRepresentation())\n")
            }
            let persistentKeepAlive = peer.persistentKeepAlive ?? 0
            wgSettings.append("persistent_keepalive_interval=\(persistentKeepAlive)\n")
            if (!peer.allowedIPs.isEmpty) {
                wgSettings.append("replace_allowed_ips=true\n")
                for ip in peer.allowedIPs {
                    wgSettings.append("allowed_ip=\(ip.stringRepresentation())\n")
                }
            }
        }
        return wgSettings
    }

    func generateNetworkSettings() -> NEPacketTunnelNetworkSettings {

        // Remote address

        /* iOS requires a tunnel endpoint, whereas in WireGuard it's valid for
         * a tunnel to have no endpoint, or for there to be many endpoints, in
         * which case, displaying a single one in settings doesn't really
         * make sense. So, we fill it in with this placeholder, which is not
         * a valid IP address that will actually route over the Internet.
         */
        var remoteAddress: String = "0.0.0.0"
        let endpointsCompact = resolvedEndpoints.compactMap({ $0 })
        if endpointsCompact.count == 1 {
            switch (endpointsCompact.first!.host) {
            case .ipv4(let address):
                remoteAddress = "\(address)"
            case .ipv6(let address):
                remoteAddress = "\(address)"
            default:
                break
            }
        }

        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: remoteAddress)

        // DNS

        let dnsServerStrings = tunnelConfiguration.interface.dns.map { $0.stringRepresentation() }
        networkSettings.dnsSettings = NEDNSSettings(servers: dnsServerStrings)

        // MTU

        let mtu = tunnelConfiguration.interface.mtu ?? 0
        if (mtu == 0) {
            // 0 imples automatic MTU, where we set overhead as 80 bytes, which is the worst case for WireGuard
            networkSettings.tunnelOverheadBytes = 80
        } else {
            networkSettings.mtu = NSNumber(value: mtu)
        }

        // Addresses from interface addresses

        var ipv4Addresses: [String] = []
        var ipv4SubnetMasks: [String] = []

        var ipv6Addresses: [String] = []
        var ipv6NetworkPrefixLengths: [NSNumber] = []

        for addressRange in tunnelConfiguration.interface.addresses {
            if (addressRange.address is IPv4Address) {
                ipv4Addresses.append("\(addressRange.address)")
                ipv4SubnetMasks.append(PacketTunnelSettingsGenerator.ipv4SubnetMaskString(of: addressRange))
            } else if (addressRange.address is IPv6Address) {
                ipv6Addresses.append("\(addressRange.address)")
                ipv6NetworkPrefixLengths.append(NSNumber(value: addressRange.networkPrefixLength))
            }
        }

        // Included routes from AllowedIPs

        var ipv4IncludedRouteAddresses: [String] = []
        var ipv4IncludedRouteSubnetMasks: [String] = []

        var ipv6IncludedRouteAddresses: [String] = []
        var ipv6IncludedRouteNetworkPrefixLengths: [NSNumber] = []

        for peer in tunnelConfiguration.peers {
            for addressRange in peer.allowedIPs {
                if (addressRange.address is IPv4Address) {
                    ipv4IncludedRouteAddresses.append("\(addressRange.address)")
                    ipv4IncludedRouteSubnetMasks.append(PacketTunnelSettingsGenerator.ipv4SubnetMaskString(of: addressRange))
                } else if (addressRange.address is IPv6Address) {
                    ipv6IncludedRouteAddresses.append("\(addressRange.address)")
                    ipv6IncludedRouteNetworkPrefixLengths.append(NSNumber(value: addressRange.networkPrefixLength))
                }
            }
        }

        // Excluded routes from endpoints

        var ipv4ExcludedRouteAddresses: [String] = []
        var ipv4ExcludedRouteSubnetMasks: [String] = []

        var ipv6ExcludedRouteAddresses: [String] = []
        var ipv6ExcludedRouteNetworkPrefixLengths: [NSNumber] = []

        for endpoint in resolvedEndpoints {
            guard let endpoint = endpoint else { continue }
            switch (endpoint.host) {
            case .ipv4(let address):
                ipv4ExcludedRouteAddresses.append("\(address)")
                ipv4ExcludedRouteSubnetMasks.append("255.255.255.255") // A single IPv4 address
            case .ipv6(let address):
                ipv6ExcludedRouteAddresses.append("\(address)")
                ipv6ExcludedRouteNetworkPrefixLengths.append(NSNumber(value: UInt8(128))) // A single IPv6 address
            default:
                fatalError()
            }
        }

        // Apply IPv4 settings

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

        // Apply IPv6 settings

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

        // Done

        return networkSettings
    }

    static func ipv4SubnetMaskString(of addressRange: IPAddressRange) -> String {
        let n: UInt8 = addressRange.networkPrefixLength
        assert(n <= 32)
        var octets: [UInt8] = [0, 0, 0, 0]
        let subnetMask: UInt32 = n > 0 ? ~UInt32(0) << (32 - n) : UInt32(0)
        octets[0] = UInt8(truncatingIfNeeded: subnetMask >> 24)
        octets[1] = UInt8(truncatingIfNeeded: subnetMask >> 16)
        octets[2] = UInt8(truncatingIfNeeded: subnetMask >> 8)
        octets[3] = UInt8(truncatingIfNeeded: subnetMask)
        return octets.map { String($0) }.joined(separator: ".")
    }
}

private extension Data {
    func hexEncodedString() -> String {
        return self.map { String(format: "%02x", $0) }.joined()
    }
}
