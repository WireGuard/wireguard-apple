// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation
import Network

public struct InterfaceConfiguration {
    public var privateKey: PrivateKey
    public var addresses = [IPAddressRange]()
    public var Jc: UInt16?
    public var Jmin: UInt16?
    public var Jmax: UInt16?
    public var S1: UInt16?
    public var S2: UInt16?
    public var H1: UInt32?
    public var H2: UInt32?
    public var H3: UInt32?
    public var H4: UInt32?
    public var listenPort: UInt16?
    public var mtu: UInt16?
    public var dns = [DNSServer]()
    public var dnsSearch = [String]()

    public init(privateKey: PrivateKey) {
        self.privateKey = privateKey
    }
}

extension InterfaceConfiguration: Equatable {
    public static func == (lhs: InterfaceConfiguration, rhs: InterfaceConfiguration) -> Bool {
        let lhsAddresses = lhs.addresses.filter { $0.address is IPv4Address } + lhs.addresses.filter { $0.address is IPv6Address }
        let rhsAddresses = rhs.addresses.filter { $0.address is IPv4Address } + rhs.addresses.filter { $0.address is IPv6Address }

        return lhs.privateKey == rhs.privateKey &&
            lhsAddresses == rhsAddresses &&
            lhs.listenPort == rhs.listenPort &&
            lhs.mtu == rhs.mtu &&
            lhs.dns == rhs.dns &&
            lhs.dnsSearch == rhs.dnsSearch
    }
}
