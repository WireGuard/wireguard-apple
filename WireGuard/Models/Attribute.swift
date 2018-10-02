//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation

struct Attribute {

    enum Key: String, CaseIterable {
        case address = "Address"
        case allowedIPs = "AllowedIPs"
        case dns = "DNS"
        case endpoint = "Endpoint"
        case listenPort = "ListenPort"
        case mtu = "MTU"
        case persistentKeepalive = "PersistentKeepalive"
        case presharedKey = "PresharedKey"
        case privateKey = "PrivateKey"
        case publicKey = "PublicKey"
    }

    private static let separatorPattern = (try? NSRegularExpression(pattern: "\\s|=", options: []))!

    let line: String
    let key: Key
    let stringValue: String
    var arrayValue: [String] {
        return stringValue.commaSeparatedToArray()
    }

    static func match(line: String) -> Attribute? {
        guard let equalsIndex = line.firstIndex(of: "=") else { return nil }
        let keyString = line[..<equalsIndex].trimmingCharacters(in: .whitespaces)
        let value = line[line.index(equalsIndex, offsetBy: 1)...].trimmingCharacters(in: .whitespaces)
        guard let key = Key.allCases.first(where: { $0.rawValue.lowercased() == keyString.lowercased() }) else { return nil }

        return Attribute(line: line, key: key, stringValue: value)
    }

}
