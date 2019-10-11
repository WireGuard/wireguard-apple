// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation
import Security

class Keychain {
    static func openReference(called ref: Data) -> String? {
        var result: CFTypeRef?
        let ret =  SecItemCopyMatching([kSecClass as String: kSecClassGenericPassword,
                                        kSecValuePersistentRef as String: ref,
                                        kSecReturnData as String: true] as CFDictionary,
                                       &result)
        if ret != errSecSuccess || result == nil {
            wg_log(.error, message: "Unable to open config from keychain: \(ret)")
            return nil
        }
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: String.Encoding.utf8)
    }

    static func makeReference(containing value: String, called name: String, previouslyReferencedBy oldRef: Data? = nil) -> Data? {
        var ret: OSStatus
        guard var id = Bundle.main.bundleIdentifier else {
            wg_log(.error, staticMessage: "Unable to determine bundle identifier")
            return nil
        }
        if id.hasSuffix(".network-extension") {
            id.removeLast(".network-extension".count)
        }
        var items: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrLabel as String: "WireGuard Tunnel: " + name,
                                    kSecAttrAccount as String: name + ": " + UUID().uuidString,
                                    kSecAttrDescription as String: "wg-quick(8) config",
                                    kSecAttrService as String: id,
                                    kSecValueData as String: value.data(using: .utf8) as Any,
                                    kSecReturnPersistentRef as String: true]

        #if os(iOS)
        items[kSecAttrAccessGroup as String] = FileManager.appGroupId
        items[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        #elseif os(macOS)
        items[kSecAttrSynchronizable as String] = false
        items[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        guard let extensionPath = Bundle.main.builtInPlugInsURL?.appendingPathComponent("WireGuardNetworkExtension.appex").path else {
            wg_log(.error, staticMessage: "Unable to determine app extension path")
            return nil
        }
        var extensionApp: SecTrustedApplication?
        var mainApp: SecTrustedApplication?
        ret = SecTrustedApplicationCreateFromPath(extensionPath, &extensionApp)
        if ret != kOSReturnSuccess || extensionApp == nil {
            wg_log(.error, message: "Unable to create keychain extension trusted application object: \(ret)")
            return nil
        }
        ret = SecTrustedApplicationCreateFromPath(nil, &mainApp)
        if ret != errSecSuccess || mainApp == nil {
            wg_log(.error, message: "Unable to create keychain local trusted application object: \(ret)")
            return nil
        }
        var access: SecAccess?
        ret = SecAccessCreate((items[kSecAttrLabel as String] as? String)! as CFString,
                              [extensionApp!, mainApp!] as CFArray,
                              &access)
        if ret != errSecSuccess || access == nil {
            wg_log(.error, message: "Unable to create keychain ACL object: \(ret)")
            return nil
        }
        items[kSecAttrAccess as String] = access!
        #else
        #error("Unimplemented")
        #endif

        var ref: CFTypeRef?
        ret = SecItemAdd(items as CFDictionary, &ref)
        if ret != errSecSuccess || ref == nil {
            wg_log(.error, message: "Unable to add config to keychain: \(ret)")
            return nil
        }
        if let oldRef = oldRef {
            deleteReference(called: oldRef)
        }
        return ref as? Data
    }

    static func deleteReference(called ref: Data) {
        let ret = SecItemDelete([kSecValuePersistentRef as String: ref] as CFDictionary)
        if ret != errSecSuccess {
            wg_log(.error, message: "Unable to delete config from keychain: \(ret)")
        }
    }

    static func deleteReferences(except whitelist: Set<Data>) {
        var result: CFTypeRef?
        let ret = SecItemCopyMatching([kSecClass as String: kSecClassGenericPassword,
                                       kSecAttrService as String: Bundle.main.bundleIdentifier as Any,
                                       kSecMatchLimit as String: kSecMatchLimitAll,
                                       kSecReturnPersistentRef as String: true] as CFDictionary,
                                      &result)
        if ret != errSecSuccess || result == nil {
            return
        }
        guard let items = result as? [Data] else { return }
        for item in items {
            if !whitelist.contains(item) {
                deleteReference(called: item)
            }
        }
    }

    static func verifyReference(called ref: Data) -> Bool {
        return SecItemCopyMatching([kSecClass as String: kSecClassGenericPassword,
                                    kSecValuePersistentRef as String: ref] as CFDictionary,
                                   nil) != errSecItemNotFound
    }
}
