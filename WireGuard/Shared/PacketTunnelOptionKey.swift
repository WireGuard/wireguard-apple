// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation

enum PacketTunnelOptionKey: String {

    case interfaceName, wireguardSettings, remoteAddress, dnsServers, mtu,

    // IPv4 settings
    ipv4Addresses, ipv4SubnetMasks,
    ipv4IncludedRouteAddresses, ipv4IncludedRouteSubnetMasks,
    ipv4ExcludedRouteAddresses, ipv4ExcludedRouteSubnetMasks,

    // IPv6 settings
    ipv6Addresses, ipv6NetworkPrefixLengths,
    ipv6IncludedRouteAddresses, ipv6IncludedRouteNetworkPrefixLengths,
    ipv6ExcludedRouteAddresses, ipv6ExcludedRouteNetworkPrefixLengths
}

extension Dictionary where Key == String {
    subscript(key: PacketTunnelOptionKey) -> Value? {
        get {
            return self[key.rawValue]
        }
        set(value) {
            self[key.rawValue] = value
        }
    }
}
