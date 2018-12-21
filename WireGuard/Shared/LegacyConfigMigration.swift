// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import Network
import NetworkExtension

protocol LegacyModel: Decodable {
    associatedtype Model

    var migrated: Model { get }
}

struct LegacyDNSServer: LegacyModel {
    let address: IPAddress

    var migrated: DNSServer {
        return DNSServer(address: address)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var data = try container.decode(Data.self)
        let ipAddressFromData: IPAddress? = {
            switch data.count {
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

extension Array where Element == LegacyDNSServer {
    var migrated: [DNSServer] {
        return map { $0.migrated }
    }
}

struct LegacyEndpoint: LegacyModel {
    let host: Network.NWEndpoint.Host
    let port: Network.NWEndpoint.Port

    var migrated: Endpoint {
        return Endpoint(host: host, port: port)
    }

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

    enum DecodingError: Error {
        case invalidData
    }
}

struct LegacyInterfaceConfiguration: LegacyModel {
    let name: String
    let privateKey: Data
    let addresses: [LegacyIPAddressRange]
    let listenPort: UInt16?
    let mtu: UInt16?
    let dns: [LegacyDNSServer]

    var migrated: InterfaceConfiguration {
        var interface = InterfaceConfiguration(name: name, privateKey: privateKey)
        interface.addresses = addresses.migrated
        interface.listenPort = listenPort
        interface.mtu = mtu
        interface.dns = dns.migrated
        return interface
    }
}

struct LegacyIPAddressRange: LegacyModel {
    let address: IPAddress
    let networkPrefixLength: UInt8

    var migrated: IPAddressRange {
        return IPAddressRange(address: address, networkPrefixLength: networkPrefixLength)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var data = try container.decode(Data.self)
        networkPrefixLength = data.removeLast()
        let ipAddressFromData: IPAddress? = {
            switch data.count {
            case 4: return IPv4Address(data)
            case 16: return IPv6Address(data)
            default: return nil
            }
        }()
        guard let ipAddress = ipAddressFromData else { throw DecodingError.invalidData }
        address = ipAddress
    }

    enum DecodingError: Error {
        case invalidData
    }
}

extension Array where Element == LegacyIPAddressRange {
    var migrated: [IPAddressRange] {
        return map { $0.migrated }
    }
}

struct LegacyPeerConfiguration: LegacyModel {
    let publicKey: Data
    let preSharedKey: Data?
    let allowedIPs: [LegacyIPAddressRange]
    let endpoint: LegacyEndpoint?
    let persistentKeepAlive: UInt16?

    var migrated: PeerConfiguration {
        var configuration = PeerConfiguration(publicKey: publicKey)
        configuration.preSharedKey = preSharedKey
        configuration.allowedIPs = allowedIPs.migrated
        configuration.endpoint = endpoint?.migrated
        configuration.persistentKeepAlive = persistentKeepAlive
        return configuration
    }
}

extension Array where Element == LegacyPeerConfiguration {
    var migrated: [PeerConfiguration] {
        return map { $0.migrated }
    }
}

final class LegacyTunnelConfiguration: LegacyModel {
    let interface: LegacyInterfaceConfiguration
    let peers: [LegacyPeerConfiguration]

    var migrated: TunnelConfiguration {
        return TunnelConfiguration(interface: interface.migrated, peers: peers.migrated)
    }
}

extension NETunnelProviderProtocol {

    @discardableResult
    func migrateConfigurationIfNeeded() -> Bool {
        guard let configurationVersion = providerConfiguration?["tunnelConfigurationVersion"] as? Int else { return false }
        if configurationVersion == 1 {
            migrateFromConfigurationV1()
        } else {
            fatalError("No migration from configuration version \(configurationVersion) exists.")
        }
        return true
    }

    private func migrateFromConfigurationV1() {
        guard let serializedTunnelConfiguration = providerConfiguration?["tunnelConfiguration"] as? Data else { return }
        guard let configuration = try? JSONDecoder().decode(LegacyTunnelConfiguration.self, from: serializedTunnelConfiguration) else { return }
        providerConfiguration = [Keys.wgQuickConfig.rawValue: configuration.migrated.asWgQuickConfig()]
    }

}
