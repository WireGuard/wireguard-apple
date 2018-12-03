// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import SystemConfiguration

class InternetReachability {

    enum Status {
        case unknown
        case notReachable
        case reachableOverWiFi
        case reachableOverCellular
    }

    static func currentStatus() -> Status {
        var status: Status = .unknown
        if let reachabilityRef = InternetReachability.reachabilityRef() {
            var flags = SCNetworkReachabilityFlags(rawValue: 0)
            SCNetworkReachabilityGetFlags(reachabilityRef, &flags)
            status = Status(reachabilityFlags: flags)
        }
        return status
    }

    private static func reachabilityRef() -> SCNetworkReachability? {
        let addrIn = sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size),
                                 sin_family: sa_family_t(AF_INET),
                                 sin_port: 0,
                                 sin_addr: in_addr(s_addr: 0),
                                 sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        return withUnsafePointer(to: addrIn) { (addrInPtr) -> SCNetworkReachability? in
            addrInPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { (addrPtr) -> SCNetworkReachability? in
                return SCNetworkReachabilityCreateWithAddress(nil, addrPtr)
            }
        }
    }
}

extension InternetReachability.Status {
    init(reachabilityFlags flags: SCNetworkReachabilityFlags) {
        var status: InternetReachability.Status = .notReachable
        if (flags.contains(.reachable)) {
            if (flags.contains(.isWWAN)) {
                status = .reachableOverCellular
            } else {
                status = .reachableOverWiFi
            }
        }
        self = status
    }
}
