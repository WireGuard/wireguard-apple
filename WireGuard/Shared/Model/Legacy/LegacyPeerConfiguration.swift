// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation

struct LegacyPeerConfiguration: Codable {
    let publicKey: Data
    let preSharedKey: Data?
    let allowedIPs: [LegacyIPAddressRange]
    let endpoint: LegacyEndpoint?
    let persistentKeepAlive: UInt16?
}

extension LegacyPeerConfiguration {
    var migrated: PeerConfiguration {
        var configuration = PeerConfiguration(publicKey: publicKey)
        configuration.preSharedKey = preSharedKey
        configuration.allowedIPs = allowedIPs.migrated
        configuration.endpoint = endpoint?.migrated
        configuration.persistentKeepAlive = persistentKeepAlive
        return configuration
    }
}

extension Array where Element == LegacyPeerConfiguration {
    var migrated: [PeerConfiguration] {
        return map { $0.migrated }
    }
}
