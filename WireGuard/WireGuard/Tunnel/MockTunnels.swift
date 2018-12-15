// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import NetworkExtension

// Creates mock tunnels for the iOS Simulator.

#if targetEnvironment(simulator)
class MockTunnels {
    static let tunnelNames = [
        "demo",
        "edgesecurity",
        "home",
        "office"
    ]
    static let address = "192.168.4.184/24"
    static let dnsServers = ["8.8.8.8", "4.4.4.4"]
    static let endpoint = "demo.wireguard.com:12912"
    static let allowedIPs = "0.0.0.0/0"

    static func createMockTunnels() -> [NETunnelProviderManager] {
        return tunnelNames.map { tunnelName -> NETunnelProviderManager in

            var interface = InterfaceConfiguration(name: tunnelName, privateKey: Curve25519.generatePrivateKey())
            interface.addresses = [IPAddressRange(from: address)!]
            interface.dns = dnsServers.map { DNSServer(from: $0)! }

            var peer = PeerConfiguration(publicKey: Curve25519.generatePublicKey(fromPrivateKey: Curve25519.generatePrivateKey()))
            peer.endpoint = Endpoint(from: endpoint)
            peer.allowedIPs = [IPAddressRange(from: allowedIPs)!]

            let tunnelConfiguration = TunnelConfiguration(interface: interface, peers: [peer])

            let tunnelProviderManager = NETunnelProviderManager()
            tunnelProviderManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration)
            tunnelProviderManager.localizedDescription = tunnelName
            tunnelProviderManager.isEnabled = true

            return tunnelProviderManager
        }
    }
}
#endif
