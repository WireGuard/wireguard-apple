//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation

extension Interface {

    var publicKey: String? {
        if let privateKeyString = privateKey, let privateKey = Data(base64Encoded: privateKeyString) {
            var publicKey = Data(count: 32)
            privateKey.withUnsafeBytes({ (privateKeyBytes) -> Void in
                publicKey.withUnsafeMutableBytes({ (mutableBytes) -> Void in
                    curve25519_derive_public_key(mutableBytes, privateKeyBytes)
                })
            })
            return publicKey.base64EncodedString()
        } else {
            return nil
        }
    }

    func validate() throws {
        guard let privateKey = privateKey, !privateKey.isEmpty else {
            throw InterfaceValidationError.emptyPrivateKey
        }

        guard privateKey.isBase64() else {
            throw InterfaceValidationError.invalidPrivateKey
        }

        try addresses?.commaSeparatedToArray().forEach { address in
            do {
                try _ = CIDRAddress(stringRepresentation: address)
            } catch {
                throw InterfaceValidationError.invalidAddress(cause: error)
            }
        }

        try dns?.commaSeparatedToArray().forEach { address in
            do {
                try _ = Endpoint(endpointString: address, needsPort: false)
            } catch {
                throw InterfaceValidationError.invalidDNSServer(cause: error)
            }
        }
    }

    func parse(attribute: Attribute) throws {
        switch attribute.key {
        case .address:
            addresses = attribute.stringValue
        case .dns:
            dns = attribute.stringValue
        case .listenPort:
            if let port = Int16(attribute.stringValue) {
                listenPort = port
            }
        case .mtu:
            if let mtu = Int32(attribute.stringValue) {
                self.mtu = mtu
            }
        case .privateKey:
            privateKey = attribute.stringValue
        default:
            throw TunnelParseError.invalidLine(attribute.line)
        }
    }

    func export() -> String {
        var exportString = "[Interface]\n"
        if let privateKey = privateKey {
            exportString.append("PrivateKey=\(privateKey)\n")
        }
        if let addresses = addresses {
            exportString.append("Address=\(addresses)\n")
        }
        if let dns = dns {
            exportString.append("DNS=\(dns)\n")
        }
        if mtu > 0 {
            exportString.append("MTU=\(mtu)\n")
        }
        if listenPort > 0 {
            exportString.append("ListenPort=\(listenPort)\n")
        }

        exportString.append("\n")

        return exportString
    }

}

enum InterfaceValidationError: Error {
    case emptyPrivateKey
    case invalidPrivateKey
    case invalidAddress(cause: Error)
    case invalidDNSServer(cause: Error)
}
