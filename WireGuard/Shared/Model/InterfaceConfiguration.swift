// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation
import Network

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

extension InterfaceConfiguration: Equatable {
    static func == (lhs: InterfaceConfiguration, rhs: InterfaceConfiguration) -> Bool {
        let lhsAddresses = lhs.addresses.filter { $0.address is IPv4Address } + lhs.addresses.filter { $0.address is IPv6Address }
        let rhsAddresses = rhs.addresses.filter { $0.address is IPv4Address } + rhs.addresses.filter { $0.address is IPv6Address }

        return lhs.privateKey == rhs.privateKey &&
            lhsAddresses == rhsAddresses &&
            lhs.listenPort == rhs.listenPort &&
            lhs.mtu == rhs.mtu &&
            lhs.dns == rhs.dns
    }
}
