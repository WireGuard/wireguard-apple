//
//  Tunnel+Extension.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 04-08-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import Foundation
import CoreData

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

    private func generateInterfaceProviderConfiguration(_ interface: Interface) -> String {
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

    private func generatePeerProviderConfiguration(_ peer: Peer) -> String {
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
        if let allowedIPs = peer.allowedIPs?.commaSeparatedToArray() {
            allowedIPs.forEach {
                settingsString += "allowed_ip=\($0.trimmingCharacters(in: .whitespaces))\n"
            }
        }

        return settingsString
    }

    func validate() throws {
        let nameRegex = "[a-zA-Z0-9_=+.-]{1,15}"
        let nameTest = NSPredicate(format: "SELF MATCHES %@", nameRegex)
        guard let title = title, nameTest.evaluate(with: title) else {
            throw TunnelValidationError.invalidTitle
        }

        let fetchRequest: NSFetchRequest<Tunnel> = Tunnel.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", title)
        guard (try? managedObjectContext?.count(for: fetchRequest)) == 1 else {
            throw TunnelValidationError.titleExists
        }

        guard let interface = interface else {
            throw TunnelValidationError.nilInterface
        }

        try interface.validate()

        guard let peers = peers else {
            throw TunnelValidationError.nilPeers
        }

        try peers.forEach {
            guard let peer = $0 as? Peer else {
                throw TunnelValidationError.invalidPeer
            }

            try peer.validate()
        }
    }

    static func fromConfig(_ text: String, context: NSManagedObjectContext) throws -> Tunnel {
        let lines = text.split(separator: "\n")

        var currentPeer: Peer?
        var isInInterfaceSection = false

        var tunnel: Tunnel!
        context.performAndWait {
            tunnel = Tunnel(context: context)
            tunnel.interface = Interface(context: context)
        }
        tunnel.tunnelIdentifier = UUID().uuidString

        for line in lines {
            var trimmedLine: String
            if let commentRange = line.range(of: "#") {
                trimmedLine = String(line[..<commentRange.lowerBound])
            } else {
                trimmedLine = String(line)
            }

            trimmedLine = trimmedLine.trimmingCharacters(in: .whitespaces)

            guard trimmedLine.count > 0 else { continue }

            if "[interface]" == line.lowercased() {
                currentPeer = nil
                isInInterfaceSection = true
            } else if "[peer]" == line.lowercased() {
                context.performAndWait { currentPeer = Peer(context: context) }
                tunnel.insertIntoPeers(currentPeer!, at: tunnel.peers?.count ?? 0)
                isInInterfaceSection = false
            } else if isInInterfaceSection, let attribute = Attribute.match(line: String(line)) {
                try tunnel.interface!.parse(attribute: attribute)
            } else if let currentPeer = currentPeer, let attribute = Attribute.match(line: String(line)) {
                try currentPeer.parse(attribute: attribute)
            } else {
                throw TunnelParseError.invalidLine(String(line))
            }
        }

        if !isInInterfaceSection && currentPeer == nil {
            throw TunnelParseError.noConfigInfo
        }

        return tunnel
    }

    func export() -> String {
        var exportString = ""
        if let interfaceExport = self.interface?.export() {
            exportString.append(interfaceExport)
        }

        if let peers = peers?.array as? [Peer] {
            peers.forEach {
                exportString.append($0.export())
            }
        }

        return exportString
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

enum TunnelValidationError: Error {
    case invalidTitle
    case titleExists
    case nilInterface
    case nilPeers
    case invalidPeer
}

enum TunnelParseError: Error {
    case invalidLine(_ line: String)
    case noConfigInfo
}
