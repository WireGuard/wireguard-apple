// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import Foundation
import Network

@available(OSX 10.14, iOS 12.0, *)
struct IPAddressRange {
    let address: IPAddress
    var networkPrefixLength: UInt8
}

// MARK: Converting to and from String
// For use in the UI

extension IPAddressRange {
    init?(from string: String) {
        guard let indexOfSlash = string.lastIndex(of: "/") else { return nil }
        let indexOfNetworkPrefixLength = string.index(after: indexOfSlash)
        guard (indexOfNetworkPrefixLength < string.endIndex) else { return nil }
        let addressString = String(string[string.startIndex ..< indexOfSlash])
        if let addr = IPv4Address(addressString) {
            address = addr
        } else if let addr = IPv6Address(addressString) {
            address = addr
        } else {
            return nil
        }
        let networkPrefixLengthSubstring = string[indexOfNetworkPrefixLength ..< string.endIndex]
        if let npl = UInt8(networkPrefixLengthSubstring) {
            if (address is IPv4Address) {
                networkPrefixLength = min(npl, 32)
            } else if (address is IPv6Address) {
                networkPrefixLength = min(npl, 128)
            } else {
                fatalError()
            }
        } else {
            return nil
        }
    }
    func stringRepresentation() -> String {
        return "\(address)/\(networkPrefixLength)"
    }
}

// MARK: Codable
// For serializing to disk

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
