// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation
import Network

extension IPv4Address {
    init?(addrInfo: addrinfo) {
        guard addrInfo.ai_family == AF_INET else { return nil }

        let addressData = addrInfo.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: MemoryLayout<sockaddr_in>.size) { (ptr) -> Data in
            return Data(bytes: &ptr.pointee.sin_addr, count: MemoryLayout<in_addr>.size)
        }

        if let ipAddress = IPv4Address(addressData) {
            self = ipAddress
        } else {
            return nil
        }
    }
}

extension IPv6Address {
    init?(addrInfo: addrinfo) {
        guard addrInfo.ai_family == AF_INET6 else { return nil }

        let addressData = addrInfo.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: MemoryLayout<sockaddr_in6>.size) { (ptr) -> Data in
            return Data(bytes: &ptr.pointee.sin6_addr, count: MemoryLayout<in6_addr>.size)
        }

        if let ipAddress = IPv6Address(addressData) {
            self = ipAddress
        } else {
            return nil
        }
    }
}
