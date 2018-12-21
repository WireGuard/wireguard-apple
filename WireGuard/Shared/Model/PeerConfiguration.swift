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
