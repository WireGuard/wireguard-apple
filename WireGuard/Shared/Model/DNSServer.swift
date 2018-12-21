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

extension DNSServer: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringRepresentation)
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()
        let addressString = try values.decode(String.self)
        
        if let address = IPv4Address(addressString) {
            self.address = address
        } else if let address = IPv6Address(addressString) {
            self.address = address
        } else {
            throw DecodingError.invalidData
        }
    }

    enum DecodingError: Error {
        case invalidData
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
