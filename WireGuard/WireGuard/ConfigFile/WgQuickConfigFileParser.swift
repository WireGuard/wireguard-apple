// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation

class WgQuickConfigFileParser {

    enum ParserState {
        case inInterfaceSection
        case inPeerSection
        case notInASection
    }

    enum ParseError: Error {
        case invalidLine(_ line: String.SubSequence)
        case noInterface
        case invalidInterface
        case multipleInterfaces
        case multiplePeersWithSamePublicKey
        case invalidPeer
    }

    static func parse(_ text: String, name: String) throws -> TunnelConfiguration {

        assert(!name.isEmpty)

        func collate(interfaceAttributes attributes: [String: String]) -> InterfaceConfiguration? {
            // required wg fields
            guard let privateKeyString = attributes["PrivateKey"] else { return nil }
            guard let privateKey = Data(base64Encoded: privateKeyString), privateKey.count == 32 else { return nil }
            var interface = InterfaceConfiguration(name: name, privateKey: privateKey)
            // other wg fields
            if let listenPortString = attributes["ListenPort"] {
                guard let listenPort = UInt16(listenPortString) else { return nil }
                interface.listenPort = listenPort
            }
            // wg-quick fields
            if let addressesString = attributes["Address"] {
                var addresses: [IPAddressRange] = []
                for addressString in addressesString.split(separator: ",") {
                    let trimmedString = addressString.trimmingCharacters(in: .whitespaces)
                    guard let address = IPAddressRange(from: trimmedString) else { return nil }
                    addresses.append(address)
                }
                interface.addresses = addresses
            }
            if let dnsString = attributes["DNS"] {
                var dnsServers: [DNSServer] = []
                for dnsServerString in dnsString.split(separator: ",") {
                    let trimmedString = dnsServerString.trimmingCharacters(in: .whitespaces)
                    guard let dnsServer = DNSServer(from: trimmedString) else { return nil }
                    dnsServers.append(dnsServer)
                }
                interface.dns = dnsServers
            }
            if let mtuString = attributes["MTU"] {
                guard let mtu = UInt16(mtuString) else { return nil }
                interface.mtu = mtu
            }
            return interface
        }

        func collate(peerAttributes attributes: [String: String]) -> PeerConfiguration? {
            // required wg fields
            guard let publicKeyString = attributes["PublicKey"] else { return nil }
            guard let publicKey = Data(base64Encoded: publicKeyString), publicKey.count == 32 else { return nil }
            var peer = PeerConfiguration(publicKey: publicKey)
            // wg fields
            if let preSharedKeyString = attributes["PreSharedKey"] {
                guard let preSharedKey = Data(base64Encoded: preSharedKeyString), preSharedKey.count == 32 else { return nil }
                peer.preSharedKey = preSharedKey
            }
            if let allowedIPsString = attributes["AllowedIPs"] {
                var allowedIPs: [IPAddressRange] = []
                for allowedIPString in allowedIPsString.split(separator: ",") {
                    let trimmedString = allowedIPString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    guard let allowedIP = IPAddressRange(from: trimmedString) else { return nil }
                    allowedIPs.append(allowedIP)
                }
                peer.allowedIPs = allowedIPs
            }
            if let endpointString = attributes["Endpoint"] {
                guard let endpoint = Endpoint(from: endpointString) else { return nil }
                peer.endpoint = endpoint
            }
            if let persistentKeepAliveString = attributes["PersistentKeepalive"] {
                guard let persistentKeepAlive = UInt16(persistentKeepAliveString) else { return nil }
                peer.persistentKeepAlive = persistentKeepAlive
            }
            return peer
        }

        var interfaceConfiguration: InterfaceConfiguration?
        var peerConfigurations: [PeerConfiguration] = []

        let lines = text.split(separator: "\n")

        var parserState: ParserState = .notInASection
        var attributes: [String: String] = [:]

        for (lineIndex, line) in lines.enumerated() {
            var trimmedLine: String
            if let commentRange = line.range(of: "#") {
                trimmedLine = String(line[..<commentRange.lowerBound])
            } else {
                trimmedLine = String(line)
            }

            trimmedLine = trimmedLine.trimmingCharacters(in: .whitespaces)

            guard trimmedLine.count > 0 else { continue }
            let lowercasedLine = line.lowercased()

            if let equalsIndex = line.firstIndex(of: "=") {
                // Line contains an attribute
                let key = line[..<equalsIndex].trimmingCharacters(in: .whitespaces)
                let value = line[line.index(equalsIndex, offsetBy: 1)...].trimmingCharacters(in: .whitespaces)
                let keysWithMultipleEntriesAllowed: Set<String> = ["Address", "AllowedIPs", "DNS"]
                if let presentValue = attributes[key], keysWithMultipleEntriesAllowed.contains(key) {
                    attributes[key] = presentValue + "," + value
                } else {
                    attributes[key] = value
                }
            } else {
                if (lowercasedLine != "[interface]" && lowercasedLine != "[peer]") {
                    throw ParseError.invalidLine(line)
                }
            }

            let isLastLine: Bool = (lineIndex == lines.count - 1)

            if (isLastLine || lowercasedLine == "[interface]" || lowercasedLine == "[peer]") {
                // Previous section has ended; process the attributes collected so far
                if (parserState == .inInterfaceSection) {
                    guard let interface = collate(interfaceAttributes: attributes) else { throw ParseError.invalidInterface }
                    guard (interfaceConfiguration == nil) else { throw ParseError.multipleInterfaces }
                    interfaceConfiguration = interface
                } else if (parserState == .inPeerSection) {
                    guard let peer = collate(peerAttributes: attributes) else { throw ParseError.invalidPeer }
                    peerConfigurations.append(peer)
                }
            }

            if (lowercasedLine == "[interface]") {
                parserState = .inInterfaceSection
                attributes.removeAll()
            } else if (lowercasedLine == "[peer]") {
                parserState = .inPeerSection
                attributes.removeAll()
            }
        }

        let peerPublicKeysArray = peerConfigurations.map { $0.publicKey }
        let peerPublicKeysSet = Set<Data>(peerPublicKeysArray)
        if (peerPublicKeysArray.count != peerPublicKeysSet.count) {
            throw ParseError.multiplePeersWithSamePublicKey
        }

        if let interfaceConfiguration = interfaceConfiguration {
            let tunnelConfiguration = TunnelConfiguration(interface: interfaceConfiguration, peers: peerConfigurations)
            return tunnelConfiguration
        } else {
            throw ParseError.noInterface
        }
    }
}
