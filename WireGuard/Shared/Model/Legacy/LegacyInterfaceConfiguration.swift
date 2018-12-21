// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation

struct LegacyInterfaceConfiguration: Codable {
    let name: String
    let privateKey: Data
    let addresses: [LegacyIPAddressRange]
    let listenPort: UInt16?
    let mtu: UInt16?
    let dns: [LegacyDNSServer]
}

extension LegacyInterfaceConfiguration {
    var migrated: InterfaceConfiguration {
        var interface = InterfaceConfiguration(name: name, privateKey: privateKey)
        interface.addresses = addresses.migrated
        interface.listenPort = listenPort
        interface.mtu = mtu
        interface.dns = dns.migrated
        return interface
    }
}
