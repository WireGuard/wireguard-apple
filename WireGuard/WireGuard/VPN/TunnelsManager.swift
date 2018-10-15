//
//  TunnelsManager.swift
//  WireGuard
//
//  Created by Roopesh Chander on 13/10/18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation

class TunnelProviderManager {
    // Mock of NETunnelProviderManager
    var name: String
    var tunnelConfiguration: TunnelConfiguration
    init(tunnelConfiguration: TunnelConfiguration) {
        self.name = tunnelConfiguration.name
        self.tunnelConfiguration = tunnelConfiguration
    }
}

class TunnelContainer {
    var name: String { return tunnelProvider.name }
    let tunnelProvider: TunnelProviderManager
    var index: Int
    init(tunnel: TunnelProviderManager, index: Int) {
        self.tunnelProvider = tunnel
        self.index = index
    }
}

class TunnelsManager {

    var tunnels: [TunnelContainer]

    enum TunnelsManagerError: Error {
        case tunnelsUninitialized
    }

    init(tunnelProviders: [TunnelProviderManager]) {
        var tunnels: [TunnelContainer] = []
        for (i, tunnelProvider) in tunnelProviders.enumerated() {
            let tunnel = TunnelContainer(tunnel: tunnelProvider, index: i)
            tunnels.append(tunnel)
        }
        self.tunnels = tunnels
    }

    static func create(completionHandler: (TunnelsManager?) -> Void) {
        completionHandler(TunnelsManager(tunnelProviders: []))
    }

    func add(tunnelConfiguration: TunnelConfiguration, completionHandler: @escaping (Error?) -> Void) {
        let tunnelProvider = TunnelProviderManager(tunnelConfiguration: tunnelConfiguration)
        for tunnel in tunnels {
            tunnel.index = tunnel.index + 1
        }
        let tunnel = TunnelContainer(tunnel: tunnelProvider, index: 0)
        tunnels.insert(tunnel, at: 0)
        completionHandler(nil)
    }

    func modify(tunnel: TunnelContainer, with tunnelConfiguration: TunnelConfiguration, completionHandler: @escaping (Error?) -> Void) {
        tunnel.tunnelProvider.tunnelConfiguration = tunnelConfiguration
        completionHandler(nil)
    }

    func remove(tunnel: TunnelContainer, completionHandler: @escaping (Error?) -> Void) {
        for i in ((tunnel.index + 1) ..< tunnels.count) {
            tunnels[i].index = tunnels[i].index + 1
        }
        tunnels.remove(at: tunnel.index)
        completionHandler(nil)
    }

    func numberOfTunnels() -> Int {
        return tunnels.count
    }

    func tunnel(at index: Int) -> TunnelContainer {
        return tunnels[index]
    }
}
