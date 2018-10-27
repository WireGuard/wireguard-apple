// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import Foundation
import Network

class PacketTunnelOptionsGenerator {
    static func generateOptions(from tc: TunnelConfiguration,
                                withResolvedEndpoints resolvedEndpoints: [Endpoint?]) -> [String:NSObject] {
        var options: [String:NSObject] = [:]

        // Interface name

        options[.interfaceName] = tc.interface.name as NSObject

        // WireGuard settings

        var wgSettings = ""
        let privateKey = tc.interface.privateKey.hexEncodedString()
        wgSettings.append("private_key=\(privateKey)\n")
        if let listenPort = tc.interface.listenPort {
            wgSettings.append("listen_port=\(listenPort)\n")
        }
        if (tc.peers.count > 0) {
            wgSettings.append("replace_peers=true\n")
        }
        assert(tc.peers.count == resolvedEndpoints.count)
        for (i, peer) in tc.peers.enumerated() {
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

        options[.wireguardSettings] = wgSettings as NSObject

        // Remote address

        let remoteAddress: String
        if let firstEndpoint = resolvedEndpoints.compactMap({ $0 }).first {
            switch (firstEndpoint.host) {
            case .ipv4(let address):
                remoteAddress = "\(address)"
            case .ipv6(let address):
                remoteAddress = "\(address)"
            default:
                fatalError("Endpoint must be resolved")
            }
        } else {
            // We don't have any peer with an endpoint
            remoteAddress = ""
        }

        options[.remoteAddress] = remoteAddress as NSObject

        // DNS

        options[.dnsServers] = tc.interface.dns.map { $0.stringRepresentation() } as NSObject

        // MTU

        options[.mtu] = NSNumber(value: tc.interface.mtu ?? 0) // 0 implies auto-MTU

        // Addresses from interface addresses

        var ipv4Addresses: [String] = []
        var ipv4SubnetMasks: [String] = []

        var ipv6Addresses: [String] = []
        var ipv6NetworkPrefixLengths: [NSNumber] = []

        for addressRange in tc.interface.addresses {
            if (addressRange.address is IPv4Address) {
                ipv4Addresses.append("\(addressRange.address)")
                ipv4SubnetMasks.append(ipv4SubnetMaskString(of: addressRange))
            } else if (addressRange.address is IPv6Address) {
                ipv6Addresses.append("\(addressRange.address)")
                ipv6NetworkPrefixLengths.append(NSNumber(value: addressRange.networkPrefixLength))
            }
        }

        options[.ipv4Addresses] = ipv4Addresses as NSObject
        options[.ipv4SubnetMasks] = ipv4SubnetMasks as NSObject

        options[.ipv6Addresses] = ipv6Addresses as NSObject
        options[.ipv6NetworkPrefixLengths] = ipv6NetworkPrefixLengths as NSObject

        // Included routes from AllowedIPs

        var ipv4IncludedRouteAddresses: [String] = []
        var ipv4IncludedRouteSubnetMasks: [String] = []

        var ipv6IncludedRouteAddresses: [String] = []
        var ipv6IncludedRouteNetworkPrefixLengths: [NSNumber] = []

        for peer in tc.peers {
            for addressRange in peer.allowedIPs {
                if (addressRange.address is IPv4Address) {
                    ipv4IncludedRouteAddresses.append("\(addressRange.address)")
                    ipv4IncludedRouteSubnetMasks.append(ipv4SubnetMaskString(of: addressRange))
                } else if (addressRange.address is IPv6Address) {
                    ipv6IncludedRouteAddresses.append("\(addressRange.address)")
                    ipv6IncludedRouteNetworkPrefixLengths.append(NSNumber(value: addressRange.networkPrefixLength))
                }
            }
        }

        options[.ipv4IncludedRouteAddresses] = ipv4IncludedRouteAddresses as NSObject
        options[.ipv4IncludedRouteSubnetMasks] = ipv4IncludedRouteSubnetMasks as NSObject

        options[.ipv6IncludedRouteAddresses] = ipv6IncludedRouteAddresses as NSObject
        options[.ipv6IncludedRouteNetworkPrefixLengths] = ipv6IncludedRouteNetworkPrefixLengths as NSObject

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

        options[.ipv4ExcludedRouteAddresses] = ipv4ExcludedRouteAddresses as NSObject
        options[.ipv4ExcludedRouteSubnetMasks] = ipv4ExcludedRouteSubnetMasks as NSObject

        options[.ipv6ExcludedRouteAddresses] = ipv6ExcludedRouteAddresses as NSObject
        options[.ipv6ExcludedRouteNetworkPrefixLengths] = ipv6ExcludedRouteNetworkPrefixLengths as NSObject

        return options
    }

    static func ipv4SubnetMaskString(of addressRange: IPAddressRange) -> String {
        var n: UInt8 = addressRange.networkPrefixLength
        assert(n <= 32)
        var components: [UInt8] = []
        while (n >= 8) {
            components.append(255)
            n = n - 8
        }
        if (n > 0) {
            components.append(((1 << n) - 1) << (8 - n))
        }
        while (components.count < 4) {
            components.append(0)
        }
        assert(components.count == 4)
        return components.map { String($0) }.joined(separator: ".")
    }
}

private extension Data {
    func hexEncodedString() -> String {
        return self.map { String(format: "%02x", $0) }.joined()
    }
}
