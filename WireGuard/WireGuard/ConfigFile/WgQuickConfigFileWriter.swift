// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

class WgQuickConfigFileWriter {
    static func writeConfigFile(from tc: TunnelConfiguration) -> Data? {
        let interface = tc.interface
        var output = "[Interface]\n"
        output.append("PrivateKey = \(interface.privateKey.base64EncodedString())\n")
        if let listenPort = interface.listenPort {
            output.append("ListenPort = \(listenPort)\n")
        }
        if (!interface.addresses.isEmpty) {
            let addressString = interface.addresses.map { $0.stringRepresentation() }.joined(separator: ", ")
            output.append("Address = \(addressString)\n")
        }
        if (!interface.dns.isEmpty) {
            let dnsString = interface.dns.map { $0.stringRepresentation() }.joined(separator: ", ")
            output.append("DNS = \(dnsString)\n")
        }
        if let mtu = interface.mtu {
            output.append("MTU = \(mtu)\n")
        }

        for peer in tc.peers {
            output.append("\n[Peer]\n")
            output.append("PublicKey = \(peer.publicKey.base64EncodedString())\n")
            if let preSharedKey = peer.preSharedKey {
                output.append("PresharedKey = \(preSharedKey.base64EncodedString())\n")
            }
            if (!peer.allowedIPs.isEmpty) {
                let allowedIPsString = peer.allowedIPs.map { $0.stringRepresentation() }.joined(separator: ", ")
                output.append("AllowedIPs = \(allowedIPsString)\n")
            }
            if let endpoint = peer.endpoint {
                output.append("Endpoint = \(endpoint.stringRepresentation())\n")
            }
            if let persistentKeepAlive = peer.persistentKeepAlive {
                output.append("PersistentKeepalive = \(persistentKeepAlive)\n")
            }
        }

        return output.data(using: .utf8)
    }
}
