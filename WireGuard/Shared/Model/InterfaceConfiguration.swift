// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation

struct InterfaceConfiguration {
    var name: String
    var privateKey: Data
    var addresses = [IPAddressRange]()
    var listenPort: UInt16?
    var mtu: UInt16?
    var dns = [DNSServer]()
    
    init(name: String, privateKey: Data) {
        self.name = name
        self.privateKey = privateKey
        if name.isEmpty {
            fatalError("Empty name")
        }
        if privateKey.count != TunnelConfiguration.keyLength {
            fatalError("Invalid private key")
        }
    }
}

extension InterfaceConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case privateKey = "PrivateKey"
        case addresses = "Address"
        case listenPort = "ListenPort"
        case mtu = "MTU"
        case dns = "DNS"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        privateKey = try Data(base64Encoded: values.decode(String.self, forKey: .privateKey))!
        addresses = try values.decode([IPAddressRange].self, forKey: .addresses)
        listenPort = try? values.decode(UInt16.self, forKey: .listenPort)
        mtu = try? values.decode(UInt16.self, forKey: .mtu)
        dns = try values.decode([DNSServer].self, forKey: .dns)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(privateKey.base64EncodedString(), forKey: .privateKey)
        try container.encode(addresses, forKey: .addresses)
        if let listenPort = listenPort {
            try container.encode(listenPort, forKey: .listenPort)
        }
        if let mtu = mtu {
            try container.encode(mtu, forKey: .mtu)
        }
        try container.encode(dns, forKey: .dns)
    }
}
