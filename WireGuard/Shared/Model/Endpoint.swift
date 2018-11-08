// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import Network

@available(OSX 10.14, iOS 12.0, *)
struct Endpoint {
    let host: NWEndpoint.Host
    let port: NWEndpoint.Port
}

// MARK: Converting to and from String
// For use in the UI

extension Endpoint {
    init?(from string: String) {
        // Separation of host and port is based on 'parse_endpoint' function in
        // https://git.zx2c4.com/WireGuard/tree/src/tools/config.c
        guard (!string.isEmpty) else { return nil }
        let startOfPort: String.Index
        let hostString: String
        if (string.first! == "[") {
            // Look for IPv6-style endpoint, like [::1]:80
            let startOfHost = string.index(after: string.startIndex)
            guard let endOfHost = string.dropFirst().firstIndex(of: "]") else { return nil }
            let afterEndOfHost = string.index(after: endOfHost)
            guard (string[afterEndOfHost] == ":") else { return nil }
            startOfPort = string.index(after: afterEndOfHost)
            hostString = String(string[startOfHost ..< endOfHost])
        } else {
            // Look for an IPv4-style endpoint, like 127.0.0.1:80
            guard let endOfHost = string.firstIndex(of: ":") else { return nil }
            startOfPort = string.index(after: endOfHost)
            hostString = String(string[string.startIndex ..< endOfHost])
        }
        guard let endpointPort = NWEndpoint.Port(String(string[startOfPort ..< string.endIndex])) else { return nil }
        let invalidCharacterIndex = hostString.unicodeScalars.firstIndex { (c) -> Bool in
            return !CharacterSet.urlHostAllowed.contains(c)
        }
        guard (invalidCharacterIndex == nil) else { return nil }
        host = NWEndpoint.Host(hostString)
        port = endpointPort
    }
    func stringRepresentation() -> String {
        switch (host) {
        case .name(let hostname, _):
            return "\(hostname):\(port)"
        case .ipv4(let address):
            return "\(address):\(port)"
        case .ipv6(let address):
            return "[\(address)]:\(port)"
        }
    }
}

// MARK: Codable
// For serializing to disk

@available(OSX 10.14, iOS 12.0, *)
extension Endpoint: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.stringRepresentation())
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let endpointString = try container.decode(String.self)
        guard let endpoint = Endpoint(from: endpointString) else {
            throw DecodingError.invalidData
        }
        self = endpoint
    }
    enum DecodingError: Error {
        case invalidData
    }
}

extension Endpoint {
    func hasHostAsIPAddress() -> Bool {
        switch (host) {
        case .name(_, _):
            return false
        case .ipv4(_):
            return true
        case .ipv6(_):
            return true
        }
    }

    func hostname() -> String? {
        switch (host) {
        case .name(let hostname, _):
            return hostname
        case .ipv4(_):
            return nil
        case .ipv6(_):
            return nil
        }
    }
}
