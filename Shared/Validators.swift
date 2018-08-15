//
//  IPValidator.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 15-08-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import Foundation

enum AddressType {
    case IPv6, IPv4, other
}

public enum EndpointValidationError: Error {
    case noIpAndPort(String)
    case invalidIP(String)
    case invalidPort(String)

    var localizedDescription: String {
        switch self {
        case .noIpAndPort:
            return NSLocalizedString("EndpointValidationError.noIpAndPort", comment: "Error message for malformed endpoint.")
        case .invalidIP:
            return NSLocalizedString("EndpointValidationError.invalidIP", comment: "Error message for invalid endpoint ip.")
        case .invalidPort:
            return NSLocalizedString("EndpointValidationError.invalidPort", comment: "Error message invalid endpoint port.")
        }
    }
}
struct Endpoint {
    var ipAddress: String
    var port: Int32
    var addressType: AddressType

    init?(endpointString: String) throws {
        guard let range = endpointString.range(of: ":", options: .backwards, range: nil, locale: nil) else {
            throw EndpointValidationError.noIpAndPort(endpointString)
        }

        let ipString = endpointString[..<range.lowerBound].replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        let portString = endpointString[range.upperBound...]

        guard let port = Int32(portString), port > 0 else {
            throw EndpointValidationError.invalidPort(String(portString/*parts[1]*/))
        }

        ipAddress = String(ipString)
        let addressType = validateIpAddress(ipToValidate: ipAddress)
        guard addressType == .IPv4 || addressType == .IPv6 else {
            throw EndpointValidationError.invalidIP(ipAddress)
        }
        self.addressType = addressType

        self.port = port
    }
}

func validateIpAddress(ipToValidate: String) -> AddressType {

    var sin = sockaddr_in()
    if ipToValidate.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 {
        // IPv4 peer.
        return .IPv4
    }

    var sin6 = sockaddr_in6()
    if ipToValidate.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
        // IPv6 peer.
        return .IPv6
    }

    return .other
}
