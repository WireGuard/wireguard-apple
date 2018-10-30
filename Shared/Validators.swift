//
//  Copyright © 2018 WireGuard LLC. All Rights Reserved.
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
        var hostString: String
        if needsPort {
            guard let range = endpointString.range(of: ":", options: .backwards, range: nil, locale: nil) else {
                throw EndpointValidationError.noIpAndPort(endpointString)
            }
            hostString = String(endpointString[..<range.lowerBound])

            let portString = endpointString[range.upperBound...]

            guard let port = Int32(portString), port > 0 else {
                throw EndpointValidationError.invalidPort(String(portString/*parts[1]*/))
            }
            self.port = port
        } else {
            hostString = endpointString
        }

        hostString = hostString.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        var addressType = validateIpAddress(ipToValidate: hostString)
        let ipString: String
        if addressType == .other {
         ipString = convertToipAddress(from: hostString)
        } else {
            ipString = hostString
        }

        ipAddress = String(ipString)
        addressType = validateIpAddress(ipToValidate: ipAddress)
        guard addressType == .IPv4 || addressType == .IPv6 else {
            throw EndpointValidationError.invalidIP(ipAddress)
        }
        self.addressType = addressType
    }
}

private func convertToipAddress(from hostname: String) -> String {
    let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
    CFHostStartInfoResolution(host, .addresses, nil)
    var success: DarwinBoolean = false
    if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
        let theAddress = addresses.firstObject as? NSData {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length),
                       &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
            let numAddress = String(cString: hostname)
            return numAddress
        }
    }
    return hostname
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
        let subnetString: String.SubSequence
        if let range = stringRepresentation.range(of: "/", options: .backwards, range: nil, locale: nil) {
            let ipString = stringRepresentation[..<range.lowerBound].replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
            ipAddress = String(ipString)
            subnetString = stringRepresentation[range.upperBound...]
        } else {
            let ipString = stringRepresentation
            ipAddress = String(ipString)
            subnetString = ""
        }

        let addressType = validateIpAddress(ipToValidate: ipAddress)
        guard addressType == .IPv4 || addressType == .IPv6 else {
            throw CIDRAddressValidationError.invalidIP(ipAddress)
        }
        self.addressType = addressType

        if let subnet = Int32(subnetString) {
            switch addressType {
            case .IPv6:
                self.subnet = subnet > 128 ? 128 : subnet
            case .IPv4:
                self.subnet = subnet > 32 ? 32 : subnet
            case .other:
                self.subnet = subnet
            }
        } else {
            switch addressType {
            case .IPv4:
                subnet = 32
            case .IPv6:
                subnet = 128
            case .other:
                throw CIDRAddressValidationError.invalidSubnet(String(subnetString))
            }
        }
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

    var stringRepresentation: String {
        return "\(ipAddress)/\(subnet)"
    }
}
