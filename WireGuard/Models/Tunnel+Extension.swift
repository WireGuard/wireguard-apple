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

        providerConfiguration["title"] = self.title
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
        var settingsString = "replace_peers=true\n"

        if let hexPrivateKey = base64KeyToHex(interface.privateKey) {
            settingsString += "private_key=\(hexPrivateKey)\n"
        }
        if interface.listenPort > 0 {
            settingsString += "listen_port=\(interface.listenPort)\n"
        }
        if let dns = interface.dns {
            settingsString += "dns=\(dns)\n"
        }
        if interface.mtu > 0 {
            settingsString += "mtu=\(interface.mtu)\n"
        }

        return settingsString
    }

    private func  generatePeerProviderConfiguration(_ peer: Peer) -> String {
        var settingsString = ""

        if let hexPublicKey = base64KeyToHex(peer.publicKey) {
            settingsString += "public_key=\(hexPublicKey)"
        }
        if let presharedKey = peer.presharedKey {
            settingsString += "preshared_key=\(presharedKey)"
        }
        if let endpoint = peer.endpoint {
            settingsString += "endpoint=\(endpoint)"
        }
        if peer.persistentKeepalive > 0 {
            settingsString += "persistent_keepalive_interval=\(peer.persistentKeepalive)"
        }
        if let allowedIPs = peer.allowedIPs?.split(separator: ",") {
            allowedIPs.forEach {
                settingsString += "allowed_ip=\($0.trimmingCharacters(in: .whitespaces))"
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
