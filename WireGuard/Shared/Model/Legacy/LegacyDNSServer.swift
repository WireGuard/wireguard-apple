// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import Network

struct LegacyDNSServer: Codable {
    let address: IPAddress
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var data = try container.decode(Data.self)
        let ipAddressFromData: IPAddress? = {
            switch data.count {
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
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(address.rawValue)
    }

    enum DecodingError: Error {
        case invalidData
    }
}

extension LegacyDNSServer {
    var migrated: DNSServer {
        return DNSServer(address: address)
    }
}

extension Array where Element == LegacyDNSServer {
    var migrated: [DNSServer] {
        return map { $0.migrated }
    }
}
