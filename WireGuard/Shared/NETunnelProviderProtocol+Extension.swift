// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import NetworkExtension

private var tunnelNameKey: Void?

extension NETunnelProviderProtocol {
    
    enum Keys: String {
        case wgQuickConfig = "WgQuickConfig"
    }
    
    convenience init?(tunnelConfiguration: TunnelConfiguration) {
        self.init()
        
        let appId = Bundle.main.bundleIdentifier!
        providerBundleIdentifier = "\(appId).network-extension"
        providerConfiguration = [Keys.wgQuickConfig.rawValue: tunnelConfiguration.asWgQuickConfig()]
        
        let endpoints = tunnelConfiguration.peers.compactMap { $0.endpoint }
        if endpoints.count == 1 {
            serverAddress = endpoints[0].stringRepresentation
        } else if endpoints.isEmpty {
            serverAddress = "Unspecified"
        } else {
            serverAddress = "Multiple endpoints"
        }
        
        username = tunnelConfiguration.interface.name
    }
    
    func tunnelConfiguration(name: String?) -> TunnelConfiguration? {
        migrateConfigurationIfNeeded()
        guard let serializedConfig = providerConfiguration?[Keys.wgQuickConfig.rawValue] as? String else { return nil }
        return try? TunnelConfiguration(serializedConfig, name: name)
    }
    
}
