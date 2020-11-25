// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

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
    var rxBytes: UInt64?
    var txBytes: UInt64?
    var lastHandshakeTime: Date?

    init(publicKey: Data) {
        self.publicKey = publicKey
        if publicKey.count != TunnelConfiguration.keyLength {
            fatalError("Invalid public key")
        }
    }
}

extension PeerConfiguration: Equatable {
    static func == (lhs: PeerConfiguration, rhs: PeerConfiguration) -> Bool {
        return lhs.publicKey == rhs.publicKey &&
            lhs.preSharedKey == rhs.preSharedKey &&
            Set(lhs.allowedIPs) == Set(rhs.allowedIPs) &&
            lhs.endpoint == rhs.endpoint &&
            lhs.persistentKeepAlive == rhs.persistentKeepAlive
    }
}

extension PeerConfiguration: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(publicKey)
        hasher.combine(preSharedKey)
        hasher.combine(Set(allowedIPs))
        hasher.combine(endpoint)
        hasher.combine(persistentKeepAlive)

    }
}
