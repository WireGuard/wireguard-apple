// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import NetworkExtension

// Creates mock tunnels for the iOS Simulator.

#if targetEnvironment(simulator)
class MockTunnels {
    static let tunnelNames = [
        "demo",
        "edgesecurity",
        "home",
        "office",
        "infra-fr",
        "infra-us",
        "krantz",
        "metheny",
        "frisell"
    ]
    static let address = "192.168.%d.%d/32"
    static let dnsServers = ["8.8.8.8", "8.8.4.4"]
    static let endpoint = "demo.wireguard.com:51820"
    static let allowedIPs = "0.0.0.0/0"

    static func createMockTunnels() -> [NETunnelProviderManager] {
        return tunnelNames.map { tunnelName -> NETunnelProviderManager in

            var interface = InterfaceConfiguration(privateKey: Curve25519.generatePrivateKey())
            interface.addresses = [IPAddressRange(from: String(format: address, Int.random(in: 1 ... 10), Int.random(in: 1 ... 254)))!]
            interface.dns = dnsServers.map { DNSServer(from: $0)! }

            var peer = PeerConfiguration(publicKey: Curve25519.generatePublicKey(fromPrivateKey: Curve25519.generatePrivateKey()))
            peer.endpoint = Endpoint(from: endpoint)
            peer.allowedIPs = [IPAddressRange(from: allowedIPs)!]

            let tunnelConfiguration = TunnelConfiguration(name: tunnelName, interface: interface, peers: [peer])

            let tunnelProviderManager = NETunnelProviderManager()
            tunnelProviderManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration)
            tunnelProviderManager.localizedDescription = tunnelConfiguration.name
            tunnelProviderManager.isEnabled = true

            return tunnelProviderManager
        }
    }
}
#endif
