// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import Network

struct LegacyEndpoint: Codable {
    let host: NWEndpoint.Host
    let port: NWEndpoint.Port
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let endpointString = try container.decode(String.self)
        guard !endpointString.isEmpty else { throw DecodingError.invalidData }
        let startOfPort: String.Index
        let hostString: String
        if endpointString.first! == "[" {
            // Look for IPv6-style endpoint, like [::1]:80
            let startOfHost = endpointString.index(after: endpointString.startIndex)
            guard let endOfHost = endpointString.dropFirst().firstIndex(of: "]") else { throw DecodingError.invalidData }
            let afterEndOfHost = endpointString.index(after: endOfHost)
            guard endpointString[afterEndOfHost] == ":" else { throw DecodingError.invalidData }
            startOfPort = endpointString.index(after: afterEndOfHost)
            hostString = String(endpointString[startOfHost ..< endOfHost])
        } else {
            // Look for an IPv4-style endpoint, like 127.0.0.1:80
            guard let endOfHost = endpointString.firstIndex(of: ":") else { throw DecodingError.invalidData }
            startOfPort = endpointString.index(after: endOfHost)
            hostString = String(endpointString[endpointString.startIndex ..< endOfHost])
        }
        guard let endpointPort = NWEndpoint.Port(String(endpointString[startOfPort ..< endpointString.endIndex])) else { throw DecodingError.invalidData }
        let invalidCharacterIndex = hostString.unicodeScalars.firstIndex { char in
            return !CharacterSet.urlHostAllowed.contains(char)
        }
        guard invalidCharacterIndex == nil else { throw DecodingError.invalidData }
        host = NWEndpoint.Host(hostString)
        port = endpointPort
    }
    
    public func encode(to encoder: Encoder) throws {
        let stringRepresentation: String
        switch host {
        case .name(let hostname, _):
            stringRepresentation = "\(hostname):\(port)"
        case .ipv4(let address):
            stringRepresentation = "\(address):\(port)"
        case .ipv6(let address):
            stringRepresentation = "[\(address)]:\(port)"
        }
        
        var container = encoder.singleValueContainer()
        try container.encode(stringRepresentation)
    }

    enum DecodingError: Error {
        case invalidData
    }
}

extension LegacyEndpoint {
    var migrated: Endpoint {
        return Endpoint(host: host, port: port)
    }
}
