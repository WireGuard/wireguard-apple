// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

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
        #if os(macOS)
        providerConfiguration = ["UID": getuid()]
        #endif

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
        if let passwordReference = passwordReference,
            let config = Keychain.openReference(called: passwordReference) {
            return try? TunnelConfiguration(fromWgQuickConfig: config, called: name)
        }
        if let oldConfig = providerConfiguration?["WgQuickConfig"] as? String {
            return try? TunnelConfiguration(fromWgQuickConfig: oldConfig, called: name)
        }
        return nil
    }

    func destroyConfigurationReference() {
        guard let ref = passwordReference else { return }
        Keychain.deleteReference(called: ref)
    }

    func verifyConfigurationReference() -> Bool {
        guard let ref = passwordReference else { return false }
        return Keychain.verifyReference(called: ref)
    }

    @discardableResult
    func migrateConfigurationIfNeeded(called name: String) -> Bool {
        /* This is how we did things before we switched to putting items
         * in the keychain. But it's still useful to keep the migration
         * around so that .mobileconfig files are easier.
         */
        if let oldConfig = providerConfiguration?["WgQuickConfig"] as? String {
            #if os(macOS)
            providerConfiguration = ["UID": getuid()]
            #elseif os(iOS)
            providerConfiguration = nil
            #else
            #error("Unimplemented")
            #endif
            guard passwordReference == nil else { return true }
            wg_log(.info, message: "Migrating tunnel configuration '\(name)'")
            passwordReference = Keychain.makeReference(containing: oldConfig, called: name)
            return true
        }
        #if os(macOS)
        if passwordReference != nil && providerConfiguration?["UID"] == nil && verifyConfigurationReference() {
            providerConfiguration = ["UID": getuid()]
            return true
        }
        #elseif os(iOS)
        if #available(iOS 15, *) {
            /* Update the stored reference from the old iOS 14 one to the canonical iOS 15 one.
             * The iOS 14 ones are 96 bits, while the iOS 15 ones are 160 bits. We do this so
             * that we can have fast set exclusion in deleteReferences safely. */
            if passwordReference != nil && passwordReference!.count == 12 {
                var result: CFTypeRef?
                let ret = SecItemCopyMatching([kSecValuePersistentRef: passwordReference!,
                                               kSecReturnPersistentRef: true] as CFDictionary,
                                               &result)
                if ret != errSecSuccess || result == nil {
                    return false
                }
                guard let newReference = result as? Data else { return false }
                if !newReference.elementsEqual(passwordReference!) {
                    wg_log(.info, message: "Migrating iOS 14-style keychain reference to iOS 15-style keychain reference for '\(name)'")
                    passwordReference = newReference
                    return true
                }
            }
        }
        #endif
        return false
    }
}
