// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import Network

struct LegacyIPAddressRange: Codable {
    let address: IPAddress
    let networkPrefixLength: UInt8
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var data = try container.decode(Data.self)
        networkPrefixLength = data.removeLast()
        let ipAddressFromData: IPAddress? = {
            switch data.count {
            case 4: return IPv4Address(data)
            case 16: return IPv6Address(data)
            default: return nil
            }
        }()
        guard let ipAddress = ipAddressFromData else { throw DecodingError.invalidData }
        address = ipAddress
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let addressDataLength: Int
        if address is IPv4Address {
            addressDataLength = 4
        } else if address is IPv6Address {
            addressDataLength = 16
        } else {
            fatalError()
        }
        var data = Data(capacity: addressDataLength + 1)
        data.append(address.rawValue)
        data.append(networkPrefixLength)
        try container.encode(data)
    }

    enum DecodingError: Error {
        case invalidData
    }
}

extension LegacyIPAddressRange {
    var migrated: IPAddressRange {
        return IPAddressRange(address: address, networkPrefixLength: networkPrefixLength)
    }
}

extension Array where Element == LegacyIPAddressRange {
    var migrated: [IPAddressRange] {
        return map { $0.migrated }
    }
}
