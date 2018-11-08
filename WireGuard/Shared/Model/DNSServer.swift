// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import Network

@available(OSX 10.14, iOS 12.0, *)
struct DNSServer {
    let address: IPAddress
}

// MARK: Converting to and from String
// For use in the UI

extension DNSServer {
    init?(from addressString: String) {
        if let addr = IPv4Address(addressString) {
            address = addr
        } else if let addr = IPv6Address(addressString) {
            address = addr
        } else {
            return nil
        }
    }
    func stringRepresentation() -> String {
        return "\(address)"
    }
}

// MARK: Codable
// For serializing to disk

@available(OSX 10.14, iOS 12.0, *)
extension DNSServer: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(address.rawValue)
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var data = try container.decode(Data.self)
        let ipAddressFromData: IPAddress? = {
            switch (data.count) {
            case 4: return IPv4Address(data)
            case 16: return IPv6Address(data)
            default: return nil
            }
        }()
        guard let ipAddress = ipAddressFromData else {
            throw DecodingError.invalidData
        }
        address = ipAddress
    }
    enum DecodingError: Error {
        case invalidData
    }
}
