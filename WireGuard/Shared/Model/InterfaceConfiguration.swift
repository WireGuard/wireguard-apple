// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation

struct InterfaceConfiguration {
    var name: String?
    var privateKey: Data
    var addresses = [IPAddressRange]()
    var listenPort: UInt16?
    var mtu: UInt16?
    var dns = [DNSServer]()

    init(name: String?, privateKey: Data) {
        self.name = name
        self.privateKey = privateKey
        if privateKey.count != TunnelConfiguration.keyLength {
            fatalError("Invalid private key")
        }
    }
}
