// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation

struct PeerConfiguration {
    var publicKey: Data
    var preSharedKey: Data? {
        didSet(value) {
            if let value = value {
                if value.count != TunnelConfiguration.keyLength {
                    fatalError("Invalid preshared key")
                }
            }
        }
    }
    var allowedIPs = [IPAddressRange]()
    var endpoint: Endpoint?
    var persistentKeepAlive: UInt16?
    
    init(publicKey: Data) {
        self.publicKey = publicKey
        if publicKey.count != TunnelConfiguration.keyLength {
            fatalError("Invalid public key")
        }
    }
}

extension PeerConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case publicKey = "PublicKey"
        case preSharedKey = "PreSharedKey"
        case allowedIPs = "AllowedIPs"
        case endpoint = "Endpoint"
        case persistentKeepAlive = "PersistentKeepAlive"
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        publicKey = try Data(base64Encoded: values.decode(String.self, forKey: .publicKey))!
        if let base64PreSharedKey = try? values.decode(Data.self, forKey: .preSharedKey) {
            preSharedKey = Data(base64Encoded: base64PreSharedKey)
        } else {
            preSharedKey = nil
        }
        allowedIPs = try values.decode([IPAddressRange].self, forKey: .allowedIPs)
        endpoint = try? values.decode(Endpoint.self, forKey: .endpoint)
        persistentKeepAlive = try? values.decode(UInt16.self, forKey: .persistentKeepAlive)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(publicKey.base64EncodedString(), forKey: .publicKey)
        if let preSharedKey = preSharedKey {
            try container.encode(preSharedKey.base64EncodedString(), forKey: .preSharedKey)
        }
        
        try container.encode(allowedIPs, forKey: .allowedIPs)
        if let endpoint = endpoint {
            try container.encode(endpoint, forKey: .endpoint)
        }
        if let persistentKeepAlive = persistentKeepAlive {
            try container.encode(persistentKeepAlive, forKey: .persistentKeepAlive)
        }
    }
}
