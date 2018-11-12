// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import NetworkExtension

extension NETunnelProviderProtocol {
    convenience init?(tunnelConfiguration: TunnelConfiguration) {
        assert(!tunnelConfiguration.interface.name.isEmpty)
        guard let serializedTunnelConfiguration = try? JSONEncoder().encode(tunnelConfiguration) else { return nil }

        self.init()

        let appId = Bundle.main.bundleIdentifier!
        providerBundleIdentifier = "\(appId).network-extension"
        providerConfiguration = [
            "tunnelConfiguration": serializedTunnelConfiguration,
            "tunnelConfigurationVersion": 1
        ]

        let endpoints = tunnelConfiguration.peers.compactMap({$0.endpoint})
        if endpoints.count == 1 {
            serverAddress = endpoints.first!.stringRepresentation()
        } else if endpoints.isEmpty {
            serverAddress = "Unspecified"
        } else {
            serverAddress = "Multiple endpoints"
        }
        username = tunnelConfiguration.interface.name
    }

    func tunnelConfiguration() -> TunnelConfiguration? {
        guard let serializedTunnelConfiguration = providerConfiguration?["tunnelConfiguration"] as? Data else { return nil }
        return try? JSONDecoder().decode(TunnelConfiguration.self, from: serializedTunnelConfiguration)
    }
}
