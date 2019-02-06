// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import NetworkExtension

enum PacketTunnelProviderError: String, Error {
    case savedProtocolConfigurationIsInvalid
    case dnsResolutionFailure
    case couldNotStartBackend
    case couldNotDetermineFileDescriptor
    case couldNotSetNetworkSettings
}

extension NETunnelProviderProtocol {
    convenience init?(tunnelConfiguration: TunnelConfiguration, previouslyFrom old: NEVPNProtocol? = nil) {
        self.init()

        guard let name = tunnelConfiguration.name else { return nil }
        guard let appId = Bundle.main.bundleIdentifier else { return nil }
        providerBundleIdentifier = "\(appId).network-extension"
        passwordReference = Keychain.makeReference(containing: tunnelConfiguration.asWgQuickConfig(), called: name, previouslyReferencedBy: old?.passwordReference)
        if passwordReference == nil {
            return nil
        }

        let endpoints = tunnelConfiguration.peers.compactMap { $0.endpoint }
        if endpoints.count == 1 {
            serverAddress = endpoints[0].stringRepresentation
        } else if endpoints.isEmpty {
            serverAddress = "Unspecified"
        } else {
            serverAddress = "Multiple endpoints"
        }
    }

    func asTunnelConfiguration(called name: String? = nil) -> TunnelConfiguration? {
        migrateConfigurationIfNeeded(called: name ?? "unknown")
        //TODO: in the case where migrateConfigurationIfNeeded is called by the network extension,
        // before the app has started, and when there is, in fact, configuration that needs to be
        // put into the keychain, this will generate one new keychain item every time it is started,
        // until finally the app is open. Would it be possible to call saveToPreferences here? Or is
        // that generally not available to network extensions? In which case, what should our
        // behavior be?

        guard let passwordReference = passwordReference else { return nil }
        guard let config = Keychain.openReference(called: passwordReference) else { return nil }
        return try? TunnelConfiguration(fromWgQuickConfig: config, called: name)
    }

    func destroyConfigurationReference() {
        guard let ref = passwordReference else { return }
        Keychain.deleteReference(called: ref)
    }

    func verifyConfigurationReference() -> Data? {
        guard let ref = passwordReference else { return nil }
        return Keychain.verifyReference(called: ref) ? ref : nil
    }

    @discardableResult
    func migrateConfigurationIfNeeded(called name: String) -> Bool {
        /* This is how we did things before we switched to putting items
         * in the keychain. But it's still useful to keep the migration
         * around so that .mobileconfig files are easier.
         */
        guard let oldConfig = providerConfiguration?["WgQuickConfig"] as? String else { return false }
        providerConfiguration = nil
        guard passwordReference == nil else { return true }
        passwordReference = Keychain.makeReference(containing: oldConfig, called: name)
        return true
    }
}
