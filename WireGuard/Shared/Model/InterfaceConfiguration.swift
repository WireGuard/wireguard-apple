// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation

struct InterfaceConfiguration {
    var privateKey: Data
    var addresses = [IPAddressRange]()
    var listenPort: UInt16?
    var mtu: UInt16?
    var dns = [DNSServer]()

    init(privateKey: Data) {
        if privateKey.count != TunnelConfiguration.keyLength {
            fatalError("Invalid private key")
        }
        self.privateKey = privateKey
    }
}
