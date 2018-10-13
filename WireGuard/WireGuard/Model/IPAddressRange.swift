//
//  IPAddressRange.swift
//  WireGuard
//
//  Created by Roopesh Chander on 13/10/18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation
import Network

@available(OSX 10.14, iOS 12.0, *)
struct IPAddressRange {
    let address: IPAddress
    var networkPrefixLength: UInt8
}

@available(OSX 10.14, iOS 12.0, *)
extension IPAddressRange: Codable {
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
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var data = try container.decode(Data.self)
        networkPrefixLength = data.removeLast()
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
