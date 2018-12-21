// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation

final class LegacyTunnelConfiguration: Codable {
    let interface: LegacyInterfaceConfiguration
    let peers: [LegacyPeerConfiguration]
}

extension LegacyTunnelConfiguration {
    var migrated: TunnelConfiguration {
        return TunnelConfiguration(interface: interface.migrated, peers: peers.migrated)
    }
}
