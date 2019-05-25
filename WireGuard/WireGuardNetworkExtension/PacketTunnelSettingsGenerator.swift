// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

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

    func endpointUapiConfiguration() -> String {
        var wgSettings = ""
        for (index, peer) in tunnelConfiguration.peers.enumerated() {
            if let publicKey = peer.publicKey.hexKey() {
                wgSettings.append("public_key=\(publicKey)\n")
            }
            if let endpoint = resolvedEndpoints[index]?.withReresolvedIP() {
                if case .name(_, _) = endpoint.host { assert(false, "Endpoint is not resolved") }
                wgSettings.append("endpoint=\(endpoint.stringRepresentation)\n")
            }
        }
        return wgSettings
    }

    func uapiConfiguration() -> String {
        var wgSettings = ""
        if let privateKey = tunnelConfiguration.interface.privateKey.hexKey() {
            wgSettings.append("private_key=\(privateKey)\n")
        }
        if let listenPort = tunnelConfiguration.interface.listenPort {
            wgSettings.append("listen_port=\(listenPort)\n")
        }
        if !tunnelConfiguration.peers.isEmpty {
            wgSettings.append("replace_peers=true\n")
        }
        assert(tunnelConfiguration.peers.count == resolvedEndpoints.count)
        for (index, peer) in tunnelConfiguration.peers.enumerated() {
            if let publicKey = peer.publicKey.hexKey() {
                wgSettings.append("public_key=\(publicKey)\n")
            }
            if let preSharedKey = peer.preSharedKey?.hexKey() {
                wgSettings.append("preshared_key=\(preSharedKey)\n")
            }
            if let endpoint = resolvedEndpoints[index]?.withReresolvedIP() {
                if case .name(_, _) = endpoint.host { assert(false, "Endpoint is not resolved") }
                wgSettings.append("endpoint=\(endpoint.stringRepresentation)\n")
            }
            let persistentKeepAlive = peer.persistentKeepAlive ?? 0
            wgSettings.append("persistent_keepalive_interval=\(persistentKeepAlive)\n")
            if !peer.allowedIPs.isEmpty {
                wgSettings.append("replace_allowed_ips=true\n")
                peer.allowedIPs.forEach { wgSettings.append("allowed_ip=\($0.stringRepresentation)\n") }
            }
        }
        return wgSettings
    }

    func generateNetworkSettings() -> NEPacketTunnelNetworkSettings {
        /* iOS requires a tunnel endpoint, whereas in WireGuard it's valid for
         * a tunnel to have no endpoint, or for there to be many endpoints, in
         * which case, displaying a single one in settings doesn't really
         * make sense. So, we fill it in with this placeholder, which is not
         * a valid IP address that will actually route over the Internet.
         */
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        let dnsServerStrings = tunnelConfiguration.interface.dns.map { $0.stringRepresentation }
        let dnsSettings = NEDNSSettings(servers: dnsServerStrings)
        dnsSettings.matchDomains = [""] // All DNS queries must first go through the tunnel's DNS
        networkSettings.dnsSettings = dnsSettings

        let mtu = tunnelConfiguration.interface.mtu ?? 0

        /* 0 means automatic MTU. In theory, we should just do
         * `networkSettings.tunnelOverheadBytes = 80` but in
         * practice there are too many broken networks out there.
         * Instead set it to 1280. Boohoo. Maybe someday we'll
         * add a nob, maybe, or iOS will do probing for us.
         */
        if mtu == 0 {
            #if os(iOS)
            networkSettings.mtu = NSNumber(value: 1280)
            #elseif os(macOS)
            networkSettings.tunnelOverheadBytes = 80
            #else
            #error("Unimplemented")
            #endif
        } else {
            networkSettings.mtu = NSNumber(value: mtu)
        }

        let (ipv4Routes, ipv6Routes) = routes()
        let (ipv4IncludedRoutes, ipv6IncludedRoutes) = includedRoutes()

        let ipv4Settings = NEIPv4Settings(addresses: ipv4Routes.map { $0.destinationAddress }, subnetMasks: ipv4Routes.map { $0.destinationSubnetMask })
        ipv4Settings.includedRoutes = ipv4IncludedRoutes
        networkSettings.ipv4Settings = ipv4Settings

        let ipv6Settings = NEIPv6Settings(addresses: ipv6Routes.map { $0.destinationAddress }, networkPrefixLengths: ipv6Routes.map { $0.destinationNetworkPrefixLength })
        ipv6Settings.includedRoutes = ipv6IncludedRoutes
        networkSettings.ipv6Settings = ipv6Settings

        return networkSettings
    }

    private func ipv4SubnetMaskString(of addressRange: IPAddressRange) -> String {
        let length: UInt8 = addressRange.networkPrefixLength
        assert(length <= 32)
        var octets: [UInt8] = [0, 0, 0, 0]
        let subnetMask: UInt32 = length > 0 ? ~UInt32(0) << (32 - length) : UInt32(0)
        octets[0] = UInt8(truncatingIfNeeded: subnetMask >> 24)
        octets[1] = UInt8(truncatingIfNeeded: subnetMask >> 16)
        octets[2] = UInt8(truncatingIfNeeded: subnetMask >> 8)
        octets[3] = UInt8(truncatingIfNeeded: subnetMask)
        return octets.map { String($0) }.joined(separator: ".")
    }

    private func routes() -> ([NEIPv4Route], [NEIPv6Route]) {
        var ipv4Routes = [NEIPv4Route]()
        var ipv6Routes = [NEIPv6Route]()
        for addressRange in tunnelConfiguration.interface.addresses {
            if addressRange.address is IPv4Address {
                ipv4Routes.append(NEIPv4Route(destinationAddress: "\(addressRange.address)", subnetMask: ipv4SubnetMaskString(of: addressRange)))
            } else if addressRange.address is IPv6Address {
                /* Big fat ugly hack for broken iOS networking stack: the smallest prefix that will have
                 * any effect on iOS is a /120, so we clamp everything above to /120. This is potentially
                 * very bad, if various network parameters were actually relying on that subnet being
                 * intentionally small. TODO: talk about this with upstream iOS devs.
                 */
                ipv6Routes.append(NEIPv6Route(destinationAddress: "\(addressRange.address)", networkPrefixLength: NSNumber(value: min(120, addressRange.networkPrefixLength))))
            }
        }
        return (ipv4Routes, ipv6Routes)
    }

    private func includedRoutes() -> ([NEIPv4Route], [NEIPv6Route]) {
        var ipv4IncludedRoutes = [NEIPv4Route]()
        var ipv6IncludedRoutes = [NEIPv6Route]()
        for peer in tunnelConfiguration.peers {
            for addressRange in peer.allowedIPs {
                if addressRange.address is IPv4Address {
                    ipv4IncludedRoutes.append(NEIPv4Route(destinationAddress: "\(addressRange.address)", subnetMask: ipv4SubnetMaskString(of: addressRange)))
                } else if addressRange.address is IPv6Address {
                    ipv6IncludedRoutes.append(NEIPv6Route(destinationAddress: "\(addressRange.address)", networkPrefixLength: NSNumber(value: addressRange.networkPrefixLength)))
                }
            }
        }
        return (ipv4IncludedRoutes, ipv6IncludedRoutes)
    }
}
