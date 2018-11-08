// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Network
import Foundation

enum DNSResolverError: Error {
    case dnsResolutionFailed(hostnames: [String])
}

class DNSResolver {

    static func isAllEndpointsAlreadyResolved(endpoints: [Endpoint?]) -> Bool {
        for endpoint in endpoints {
            guard let endpoint = endpoint else { continue }
            if (!endpoint.hasHostAsIPAddress()) {
                return false
            }
        }
        return true
    }

    static func resolveSync(endpoints: [Endpoint?]) throws -> [Endpoint?] {
        let dispatchGroup: DispatchGroup = DispatchGroup()

        if (isAllEndpointsAlreadyResolved(endpoints: endpoints)) {
            return endpoints
        }

        var resolvedEndpoints: [Endpoint?] = Array<Endpoint?>(repeating: nil, count: endpoints.count)
        for (i, endpoint) in endpoints.enumerated() {
            guard let endpoint = endpoint else { continue }
            if (endpoint.hasHostAsIPAddress()) {
                resolvedEndpoints[i] = endpoint
            } else {
                let workItem = DispatchWorkItem {
                    resolvedEndpoints[i] = DNSResolver.resolveSync(endpoint: endpoint)
                }
                DispatchQueue.global(qos: .userInitiated).async(group: dispatchGroup, execute: workItem)
            }
        }

        dispatchGroup.wait() // TODO: Timeout?

        var hostnamesWithDnsResolutionFailure: [String] = []
        assert(endpoints.count == resolvedEndpoints.count)
        for tuple in zip(endpoints, resolvedEndpoints) {
            let endpoint = tuple.0
            let resolvedEndpoint = tuple.1
            if let endpoint = endpoint {
                if (resolvedEndpoint == nil) {
                    // DNS resolution failed
                    guard let hostname = endpoint.hostname() else { fatalError() }
                    hostnamesWithDnsResolutionFailure.append(hostname)
                }
            }
        }
        if (!hostnamesWithDnsResolutionFailure.isEmpty) {
            throw DNSResolverError.dnsResolutionFailed(hostnames: hostnamesWithDnsResolutionFailure)
        }
        return resolvedEndpoints
    }
}

extension DNSResolver {
    // Based on DNS resolution code by Jason Donenfeld <jason@zx2c4.com>
    // in parse_endpoint() in src/tools/config.c in the WireGuard codebase
    private static func resolveSync(endpoint: Endpoint) -> Endpoint? {
        var hints = addrinfo(
            ai_flags: 0,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_DGRAM, // WireGuard is UDP-only
            ai_protocol: IPPROTO_UDP, // WireGuard is UDP-only
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil)
        var resultPointer = UnsafeMutablePointer<addrinfo>(OpaquePointer(bitPattern: 0))
        switch (endpoint.host) {
        case .name(let name, _):
            // The endpoint is a hostname and needs DNS resolution
            let returnValue = getaddrinfo(
                name.cString(using: .utf8), // Hostname
                "\(endpoint.port)".cString(using: .utf8), // Port
                &hints,
                &resultPointer)
            if (returnValue == 0) {
                // getaddrinfo succeeded
                let ipv4Buffer = UnsafeMutablePointer<Int8>.allocate(capacity: Int(INET_ADDRSTRLEN))
                let ipv6Buffer = UnsafeMutablePointer<Int8>.allocate(capacity: Int(INET6_ADDRSTRLEN))
                var ipv4AddressString: String?
                var ipv6AddressString: String?
                while (resultPointer != nil) {
                    let result = resultPointer!.pointee
                    resultPointer = result.ai_next
                    if (result.ai_family == AF_INET && result.ai_addrlen == MemoryLayout<sockaddr_in>.size) {
                        var sa4 = UnsafeRawPointer(result.ai_addr)!.assumingMemoryBound(to: sockaddr_in.self).pointee
                        if (inet_ntop(result.ai_family, &sa4.sin_addr, ipv4Buffer, socklen_t(INET_ADDRSTRLEN)) != nil) {
                            ipv4AddressString = String(cString: ipv4Buffer)
                            // If we found an IPv4 address, we can stop
                            break
                        }
                    } else if (result.ai_family == AF_INET6 && result.ai_addrlen == MemoryLayout<sockaddr_in6>.size) {
                        if (ipv6AddressString != nil) {
                            // If we already have an IPv6 address, we can skip this one
                            continue
                        }
                        var sa6 = UnsafeRawPointer(result.ai_addr)!.assumingMemoryBound(to: sockaddr_in6.self).pointee
                        if (inet_ntop(result.ai_family, &sa6.sin6_addr, ipv6Buffer, socklen_t(INET6_ADDRSTRLEN)) != nil) {
                            ipv6AddressString = String(cString: ipv6Buffer)
                        }
                    }
                }
                ipv4Buffer.deallocate()
                ipv6Buffer.deallocate()
                // We prefer an IPv4 address over an IPv6 address
                if let ipv4AddressString = ipv4AddressString, let ipv4Address = IPv4Address(ipv4AddressString) {
                    return Endpoint(host: NWEndpoint.Host.ipv4(ipv4Address), port: endpoint.port)
                } else if let ipv6AddressString = ipv6AddressString, let ipv6Address = IPv6Address(ipv6AddressString) {
                    return Endpoint(host: NWEndpoint.Host.ipv6(ipv6Address), port: endpoint.port)
                } else {
                    return nil
                }
            } else {
                // getaddrinfo failed
                return nil
            }
        default:
            // The endpoint is already resolved
            return endpoint
        }
    }
}
