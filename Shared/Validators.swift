//
//  IPValidator.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 15-08-18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
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
    var port: Int32?
    var addressType: AddressType

    init?(endpointString: String, needsPort: Bool = true) throws {
        var ipString: String
        if needsPort {
            guard let range = endpointString.range(of: ":", options: .backwards, range: nil, locale: nil) else {
                throw EndpointValidationError.noIpAndPort(endpointString)
            }
            ipString = String(endpointString[..<range.lowerBound])

            let portString = endpointString[range.upperBound...]

            guard let port = Int32(portString), port > 0 else {
                throw EndpointValidationError.invalidPort(String(portString/*parts[1]*/))
            }
            self.port = port
        } else {
            ipString = endpointString
        }

        ipString = ipString.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")

        ipAddress = String(ipString)
        let addressType = validateIpAddress(ipToValidate: ipAddress)
        guard addressType == .IPv4 || addressType == .IPv6 else {
            throw EndpointValidationError.invalidIP(ipAddress)
        }
        self.addressType = addressType
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

public enum CIDRAddressValidationError: Error {
    case noIpAndSubnet(String)
    case invalidIP(String)
    case invalidSubnet(String)

    var localizedDescription: String {
        switch self {
        case .noIpAndSubnet:
            return NSLocalizedString("CIDRAddressValidationError", comment: "Error message for malformed CIDR address.")
        case .invalidIP:
            return NSLocalizedString("CIDRAddressValidationError", comment: "Error message for invalid address ip.")
        case .invalidSubnet:
            return NSLocalizedString("CIDRAddressValidationError", comment: "Error message invalid address subnet.")
        }
    }
}

struct CIDRAddress {
    var ipAddress: String
    var subnet: Int32
    var addressType: AddressType

    init?(stringRepresentation: String) throws {
        guard let range = stringRepresentation.range(of: "/", options: .backwards, range: nil, locale: nil) else {
            throw CIDRAddressValidationError.noIpAndSubnet(stringRepresentation)
        }

        let ipString = stringRepresentation[..<range.lowerBound].replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        let subnetString = stringRepresentation[range.upperBound...]

        guard let subnet = Int32(subnetString) else {
            throw CIDRAddressValidationError.invalidSubnet(String(subnetString))
        }

        ipAddress = String(ipString)
        let addressType = validateIpAddress(ipToValidate: ipAddress)
        guard addressType == .IPv4 || addressType == .IPv6 else {
            throw CIDRAddressValidationError.invalidIP(ipAddress)
        }
        self.addressType = addressType

        self.subnet = subnet
    }

    var subnetString: String {
        // We could calculate these.

        var bitMask: UInt32 = 0b11111111111111111111111111111111
        bitMask = bitMask << (32 - subnet)

        let first = UInt8(truncatingIfNeeded: bitMask >> 24)
        let second = UInt8(truncatingIfNeeded: bitMask >> 16 )
        let third = UInt8(truncatingIfNeeded: bitMask >> 8)
        let fourth = UInt8(truncatingIfNeeded: bitMask)

        return "\(first).\(second).\(third).\(fourth)"
    }
}
