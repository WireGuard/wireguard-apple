//
//  Tunnel+Extension.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 04-08-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import Foundation

extension Tunnel {
    public func generateProviderConfiguration() -> [String: Any] {
        var providerConfiguration = [String: Any]()

        providerConfiguration[PCKeys.title.rawValue] = self.title
        providerConfiguration[PCKeys.tunnelIdentifier.rawValue] = self.tunnelIdentifier
        providerConfiguration[PCKeys.endpoints.rawValue] = peers?.array.compactMap {($0 as? Peer)?.endpoint}.joined(separator: ", ")
        providerConfiguration[PCKeys.dns.rawValue] = interface?.dns
        providerConfiguration[PCKeys.addresses.rawValue] = interface?.addresses
        if let mtu = interface?.mtu, mtu > 0 {
            providerConfiguration[PCKeys.mtu.rawValue] = NSNumber(value: mtu)
        }

        var settingsString = "replace_peers=true\n"
        if let interface = interface {
            settingsString += generateInterfaceProviderConfiguration(interface)
        }

        if let peers = peers?.array as? [Peer] {
            peers.forEach {
                settingsString += generatePeerProviderConfiguration($0)
            }

        }

        providerConfiguration["settings"] = settingsString

        return providerConfiguration
    }

    private func  generateInterfaceProviderConfiguration(_ interface: Interface) -> String {
        var settingsString = ""

        if let hexPrivateKey = base64KeyToHex(interface.privateKey) {
            settingsString += "private_key=\(hexPrivateKey)\n"
        }
        if interface.listenPort > 0 {
            settingsString += "listen_port=\(interface.listenPort)\n"
        }
        if interface.mtu > 0 {
            settingsString += "mtu=\(interface.mtu)\n"
        }

        return settingsString
    }

    private func  generatePeerProviderConfiguration(_ peer: Peer) -> String {
        var settingsString = ""

        if let hexPublicKey = base64KeyToHex(peer.publicKey) {
            settingsString += "public_key=\(hexPublicKey)\n"
        }
        if let presharedKey = peer.presharedKey {
            settingsString += "preshared_key=\(presharedKey)\n"
        }
        if let endpoint = peer.endpoint {
            settingsString += "endpoint=\(endpoint)\n"
        }
        if peer.persistentKeepalive > 0 {
            settingsString += "persistent_keepalive_interval=\(peer.persistentKeepalive)\n"
        }
        if let allowedIPs = peer.allowedIPs?.split(separator: ",") {
            allowedIPs.forEach {
                settingsString += "allowed_ip=\($0.trimmingCharacters(in: .whitespaces))\n"
            }
        }

        return settingsString
    }
}

private func base64KeyToHex(_ base64: String?) -> String? {
    guard let base64 = base64 else {
        return nil
    }

    guard base64.count == 44 else {
        return nil
    }

    guard base64.last == "=" else {
        return nil
    }

    guard let keyData = Data(base64Encoded: base64) else {
        return nil
    }

    guard keyData.count == 32 else {
        return nil
    }

    let hexKey = keyData.reduce("") {$0 + String(format: "%02x", $1)}

    return hexKey
}
