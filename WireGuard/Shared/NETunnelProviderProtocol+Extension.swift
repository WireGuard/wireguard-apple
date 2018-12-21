// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import NetworkExtension

extension NETunnelProviderProtocol {
    
    enum Keys: String {
        case wgQuickConfig = "WgQuickConfigV1"
    }
    
    var tunnelConfiguration: TunnelConfiguration? {
        migrateConfigurationIfNeeded()

        let tunnelConfigurationData: Data?
        if let configurationDictionary = providerConfiguration?[Keys.wgQuickConfig.rawValue] {
            tunnelConfigurationData = try? JSONSerialization.data(withJSONObject: configurationDictionary, options: [])
        } else {
            tunnelConfigurationData = nil
        }
        
        guard tunnelConfigurationData != nil else { return nil }
        return try? JSONDecoder().decode(TunnelConfiguration.self, from: tunnelConfigurationData!)
    }
    
    convenience init?(tunnelConfiguration: TunnelConfiguration) {
        assert(!tunnelConfiguration.interface.name.isEmpty)
        
        guard let tunnelConfigData = try? JSONEncoder().encode(tunnelConfiguration) else { return nil }
        guard let tunnelConfigDictionary = try? JSONSerialization.jsonObject(with: tunnelConfigData, options: .allowFragments) else { return nil }
        
        self.init()

        let appId = Bundle.main.bundleIdentifier!
        providerBundleIdentifier = "\(appId).network-extension"
        providerConfiguration = [ Keys.wgQuickConfig.rawValue: tunnelConfigDictionary ]

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

    func hasTunnelConfiguration(tunnelConfiguration otherTunnelConfiguration: TunnelConfiguration) -> Bool {
        guard let serializedThisTunnelConfiguration = try? JSONEncoder().encode(tunnelConfiguration) else { return false }
        guard let serializedOtherTunnelConfiguration = try? JSONEncoder().encode(otherTunnelConfiguration) else { return false }
        return serializedThisTunnelConfiguration == serializedOtherTunnelConfiguration
    }
    
    @discardableResult
    func migrateConfigurationIfNeeded() -> Bool {
        guard let configurationVersion = providerConfiguration?["tunnelConfigurationVersion"] as? Int else { return false }
        if configurationVersion == 1 {
            migrateFromConfigurationV1()
        } else {
            fatalError("No migration from configuration version \(configurationVersion) exists.")
        }
        return true
    }
    
    private func migrateFromConfigurationV1() {
        guard let serializedTunnelConfiguration = providerConfiguration?["tunnelConfiguration"] as? Data else { return }
        guard let configuration = try? JSONDecoder().decode(LegacyTunnelConfiguration.self, from: serializedTunnelConfiguration) else { return }
        guard let tunnelConfigData = try? JSONEncoder().encode(configuration.migrated) else { return }
        guard let tunnelConfigDictionary = try? JSONSerialization.jsonObject(with: tunnelConfigData, options: .allowFragments) else { return }
        
        providerConfiguration = [ Keys.wgQuickConfig.rawValue: tunnelConfigDictionary ]
    }
    
}
