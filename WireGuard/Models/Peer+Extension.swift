//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation

extension Peer {

    func validate() throws {
        guard let publicKey = publicKey, !publicKey.isEmpty else {
            throw PeerValidationError.emptyPublicKey
        }

        guard publicKey.isBase64() else {
            throw PeerValidationError.invalidPublicKey
        }

        guard let allowedIPs = allowedIPs, !allowedIPs.isEmpty else {
            throw PeerValidationError.nilAllowedIps
        }

        try allowedIPs.commaSeparatedToArray().forEach { address in
            do {
                try _ = CIDRAddress(stringRepresentation: address)
            } catch {
                throw PeerValidationError.invalidAllowedIPs(cause: error)
            }
        }

        if let endpoint = endpoint {
            do {
                try _ = Endpoint(endpointString: endpoint)
            } catch {
                throw PeerValidationError.invalidEndpoint(cause: error)
            }
        }

        guard persistentKeepalive >= 0, persistentKeepalive <= 65535 else {
            throw PeerValidationError.invalidPersistedKeepAlive
        }
    }

    func parse(attribute: Attribute) throws {
        switch attribute.key {
        case .allowedIPs:
            allowedIPs = attribute.stringValue
        case .endpoint:
            endpoint = attribute.stringValue
        case .persistentKeepalive:
            if let keepAlive = Int32(attribute.stringValue) {
                persistentKeepalive = keepAlive
            }
        case .presharedKey:
            presharedKey = attribute.stringValue
        case .publicKey:
            publicKey = attribute.stringValue
        default:
            throw TunnelParseError.invalidLine(attribute.line)
        }
    }

    func export() -> String {
        var exportString = "[Peer]\n"
        if let publicKey = publicKey {
            exportString.append("PublicKey=\(publicKey)\n")
        }
        if let presharedKey = presharedKey {
            exportString.append("PresharedKey=\(presharedKey)\n")
        }
        if let allowedIPs = allowedIPs {
            exportString.append("AllowedIPs=\(allowedIPs)\n")
        }
        if let endpoint = endpoint {
            exportString.append("Endpoint=\(endpoint)\n")
        }
        if persistentKeepalive > 0 {
            exportString.append("PersistentKeepalive=\(persistentKeepalive)\n")
        }

        exportString.append("\n")

        return exportString
    }

}

enum PeerValidationError: Error {
    case emptyPublicKey
    case invalidPublicKey
    case nilAllowedIps
    case invalidAllowedIPs(cause: Error)
    case invalidEndpoint(cause: Error)
    case invalidPersistedKeepAlive
}
