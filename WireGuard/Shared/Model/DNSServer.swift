// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import Network

struct DNSServer {
    let address: IPAddress

    init(address: IPAddress) {
        self.address = address
    }
}

extension DNSServer {
    var stringRepresentation: String {
        return "\(address)"
    }

    init?(from addressString: String) {
        if let addr = IPv4Address(addressString) {
            address = addr
        } else if let addr = IPv6Address(addressString) {
            address = addr
        } else {
            return nil
        }
    }
}
