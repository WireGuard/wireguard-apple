// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

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
        let endOfIPAddress = string.lastIndex(of: "/") ?? string.endIndex
        let addressString = String(string[string.startIndex ..< endOfIPAddress])
        let address: IPAddress
        if let addr = IPv4Address(addressString) {
            address = addr
        } else if let addr = IPv6Address(addressString) {
            address = addr
        } else {
            return nil
        }
        let maxNetworkPrefixLength: UInt8 = (address is IPv4Address) ? 32 : 128
        var networkPrefixLength: UInt8
        if (endOfIPAddress < string.endIndex) { // "/" was located
            let indexOfNetworkPrefixLength = string.index(after: endOfIPAddress)
            guard (indexOfNetworkPrefixLength < string.endIndex) else { return nil }
            let networkPrefixLengthSubstring = string[indexOfNetworkPrefixLength ..< string.endIndex]
            guard let npl = UInt8(networkPrefixLengthSubstring) else { return nil }
            networkPrefixLength = min(npl, maxNetworkPrefixLength)
        } else {
            networkPrefixLength = maxNetworkPrefixLength
        }
        self.address = address
        self.networkPrefixLength = networkPrefixLength
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
