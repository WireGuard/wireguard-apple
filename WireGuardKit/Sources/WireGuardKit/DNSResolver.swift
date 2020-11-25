// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Network
import Foundation

class DNSResolver {

    static func isAllEndpointsAlreadyResolved(endpoints: [Endpoint?]) -> Bool {
        for endpoint in endpoints {
            guard let endpoint = endpoint else { continue }
            if !endpoint.hasHostAsIPAddress() {
                return false
            }
        }
        return true
    }

    static func resolveSync(endpoints: [Endpoint?]) -> [Endpoint?]? {
        let dispatchGroup = DispatchGroup()

        if isAllEndpointsAlreadyResolved(endpoints: endpoints) {
            return endpoints
        }

        var resolvedEndpoints: [Endpoint?] = Array(repeating: nil, count: endpoints.count)
        for (index, endpoint) in endpoints.enumerated() {
            guard let endpoint = endpoint else { continue }
            if endpoint.hasHostAsIPAddress() {
                resolvedEndpoints[index] = endpoint
            } else {
                let workItem = DispatchWorkItem {
                    resolvedEndpoints[index] = DNSResolver.resolveSync(endpoint: endpoint)
                }
                DispatchQueue.global(qos: .userInitiated).async(group: dispatchGroup, execute: workItem)
            }
        }

        dispatchGroup.wait() // TODO: Timeout?

        var hostnamesWithDnsResolutionFailure = [String]()
        assert(endpoints.count == resolvedEndpoints.count)
        for tuple in zip(endpoints, resolvedEndpoints) {
            let endpoint = tuple.0
            let resolvedEndpoint = tuple.1
            if let endpoint = endpoint {
                if resolvedEndpoint == nil {
                    guard let hostname = endpoint.hostname() else { fatalError() }
                    hostnamesWithDnsResolutionFailure.append(hostname)
                }
            }
        }
        if !hostnamesWithDnsResolutionFailure.isEmpty {
            wg_log(.error, message: "DNS resolution failed for the following hostnames: \(hostnamesWithDnsResolutionFailure.joined(separator: ", "))")
            return nil
        }
        return resolvedEndpoints
    }

    private static func resolveSync(endpoint: Endpoint) -> Endpoint? {
        switch endpoint.host {
        case .name(let name, _):
            var resultPointer = UnsafeMutablePointer<addrinfo>(OpaquePointer(bitPattern: 0))
            var hints = addrinfo(
                ai_flags: AI_ALL, // We set this to ALL so that we get v4 addresses even on DNS64 networks
                ai_family: AF_UNSPEC,
                ai_socktype: SOCK_DGRAM,
                ai_protocol: IPPROTO_UDP,
                ai_addrlen: 0,
                ai_canonname: nil,
                ai_addr: nil,
                ai_next: nil)
            if getaddrinfo(name, "\(endpoint.port)", &hints, &resultPointer) != 0 {
                return nil
            }
            var next = resultPointer
            var ipv4Address: IPv4Address?
            var ipv6Address: IPv6Address?
            while next != nil {
                let result = next!.pointee
                next = result.ai_next
                if result.ai_family == AF_INET && result.ai_addrlen == MemoryLayout<sockaddr_in>.size {
                    var sa4 = UnsafeRawPointer(result.ai_addr)!.assumingMemoryBound(to: sockaddr_in.self).pointee
                    ipv4Address = IPv4Address(Data(bytes: &sa4.sin_addr, count: MemoryLayout<in_addr>.size))
                    break // If we found an IPv4 address, we can stop
                } else if result.ai_family == AF_INET6 && result.ai_addrlen == MemoryLayout<sockaddr_in6>.size {
                    var sa6 = UnsafeRawPointer(result.ai_addr)!.assumingMemoryBound(to: sockaddr_in6.self).pointee
                    ipv6Address = IPv6Address(Data(bytes: &sa6.sin6_addr, count: MemoryLayout<in6_addr>.size))
                    continue // If we already have an IPv6 address, we can skip this one
                }
            }
            freeaddrinfo(resultPointer)

            // We prefer an IPv4 address over an IPv6 address
            if let ipv4Address = ipv4Address {
                return Endpoint(host: .ipv4(ipv4Address), port: endpoint.port)
            } else if let ipv6Address = ipv6Address {
                return Endpoint(host: .ipv6(ipv6Address), port: endpoint.port)
            } else {
                return nil
            }
        default:
            return endpoint
        }
    }
}

extension Endpoint {
    func withReresolvedIP() -> Endpoint {
        #if os(iOS)
        var ret = self
        let hostname: String
        switch host {
        case .name(let name, _):
            hostname = name
        case .ipv4(let address):
            hostname = "\(address)"
        case .ipv6(let address):
            hostname = "\(address)"
        @unknown default:
            fatalError()
        }

        var resultPointer = UnsafeMutablePointer<addrinfo>(OpaquePointer(bitPattern: 0))
        var hints = addrinfo(
            ai_flags: 0, // We set this to zero so that we actually resolve this using DNS64
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_DGRAM,
            ai_protocol: IPPROTO_UDP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil)
        if getaddrinfo(hostname, "\(port)", &hints, &resultPointer) != 0 || resultPointer == nil {
            return ret
        }
        let result = resultPointer!.pointee
        if result.ai_family == AF_INET && result.ai_addrlen == MemoryLayout<sockaddr_in>.size {
            var sa4 = UnsafeRawPointer(result.ai_addr)!.assumingMemoryBound(to: sockaddr_in.self).pointee
            let addr = IPv4Address(Data(bytes: &sa4.sin_addr, count: MemoryLayout<in_addr>.size))
            ret = Endpoint(host: .ipv4(addr!), port: port)
        } else if result.ai_family == AF_INET6 && result.ai_addrlen == MemoryLayout<sockaddr_in6>.size {
            var sa6 = UnsafeRawPointer(result.ai_addr)!.assumingMemoryBound(to: sockaddr_in6.self).pointee
            let addr = IPv6Address(Data(bytes: &sa6.sin6_addr, count: MemoryLayout<in6_addr>.size))
            ret = Endpoint(host: .ipv6(addr!), port: port)
        }
        freeaddrinfo(resultPointer)
        if ret.host != host {
            wg_log(.debug, message: "DNS64: mapped \(host) to \(ret.host)")
        } else {
            wg_log(.debug, message: "DNS64: mapped \(host) to itself.")
        }
        return ret
        #elseif os(macOS)
        return self
        #else
        #error("Unimplemented")
        #endif
    }
}
