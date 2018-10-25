// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import Foundation
import NetworkExtension
import os.log

class TunnelContainer {
    var name: String { return tunnelProvider.localizedDescription ?? "" }
    fileprivate let tunnelProvider: NETunnelProviderManager
    fileprivate var index: Int
    init(tunnel: NETunnelProviderManager, index: Int) {
        self.tunnelProvider = tunnel
        self.index = index
    }
    func tunnelConfiguration() -> TunnelConfiguration? {
        return (tunnelProvider.protocolConfiguration as! NETunnelProviderProtocol).tunnelConfiguration()
    }
}

protocol TunnelsManagerDelegate: class {
    func tunnelAdded(at: Int)
    func tunnelModified(at: Int)
    func tunnelsChanged()
}

class TunnelsManager {

    var tunnels: [TunnelContainer]
    weak var delegate: TunnelsManagerDelegate? = nil

    private var isAddingTunnel: Bool = false
    private var isModifyingTunnel: Bool = false
    private var isDeletingTunnel: Bool = false

    enum TunnelsManagerError: Error {
        case tunnelsUninitialized
    }

    init(tunnelProviders: [NETunnelProviderManager]) {
        var tunnels = tunnelProviders.map { TunnelContainer(tunnel: $0, index: 0) }
        tunnels.sort { $0.name < $1.name }
        for i in 0 ..< tunnels.count {
            tunnels[i].index = i
        }
        self.tunnels = tunnels
    }

    static func create(completionHandler: @escaping (TunnelsManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
            if let error = error {
                os_log("Failed to load tunnel provider managers %{public}@", log: OSLog.default, type: .debug, "\(error)")
                return
            }
            completionHandler(TunnelsManager(tunnelProviders: managers ?? []))
        }
    }

    private func insertionIndexFor(tunnelName: String) -> Int {
        // Wishlist: Use binary search instead
        for i in 0 ..< tunnels.count {
            if (tunnelName.lexicographicallyPrecedes(tunnels[i].name)) { return i }
        }
        return tunnels.count
    }

    func add(tunnelConfiguration: TunnelConfiguration, completionHandler: @escaping (TunnelContainer?, Error?) -> Void) {
        let tunnelName = tunnelConfiguration.interface.name
        assert(!tunnelName.isEmpty)

        isAddingTunnel = true
        let tunnelProviderManager = NETunnelProviderManager()
        tunnelProviderManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration)
        tunnelProviderManager.localizedDescription = tunnelName
        tunnelProviderManager.isEnabled = true

        tunnelProviderManager.saveToPreferences { [weak self] (error) in
            defer { self?.isAddingTunnel = false }
            guard (error == nil) else {
                completionHandler(nil, error)
                return
            }
            if let s = self {
                let index = s.insertionIndexFor(tunnelName: tunnelName)
                let tunnel = TunnelContainer(tunnel: tunnelProviderManager, index: index)
                for i in index ..< s.tunnels.count {
                    s.tunnels[i].index = s.tunnels[i].index + 1
                }
                s.tunnels.insert(tunnel, at: index)
                s.delegate?.tunnelAdded(at: index)
                completionHandler(tunnel, nil)
            }
        }
    }

    func modify(tunnel: TunnelContainer, with tunnelConfiguration: TunnelConfiguration, completionHandler: @escaping (Error?) -> Void) {
        let tunnelName = tunnelConfiguration.interface.name
        assert(!tunnelName.isEmpty)

        isModifyingTunnel = true

        let tunnelProviderManager = tunnel.tunnelProvider
        let isNameChanged = (tunnelName != tunnelProviderManager.localizedDescription)
        tunnelProviderManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration)
        tunnelProviderManager.localizedDescription = tunnelName
        tunnelProviderManager.isEnabled = true

        tunnelProviderManager.saveToPreferences { [weak self] (error) in
            defer { self?.isModifyingTunnel = false }
            guard (error != nil) else {
                completionHandler(error)
                return
            }
            if let s = self {
                if (isNameChanged) {
                    s.tunnels.remove(at: tunnel.index)
                    for i in tunnel.index ..< s.tunnels.count {
                        s.tunnels[i].index = s.tunnels[i].index - 1
                    }
                    let index = s.insertionIndexFor(tunnelName: tunnelName)
                    tunnel.index = index
                    for i in index ..< s.tunnels.count {
                        s.tunnels[i].index = s.tunnels[i].index + 1
                    }
                    s.tunnels.insert(tunnel, at: index)
                    s.delegate?.tunnelsChanged()
                } else {
                    s.delegate?.tunnelModified(at: tunnel.index)
                }
                completionHandler(nil)
            }
        }
    }

    func remove(tunnel: TunnelContainer, completionHandler: @escaping (Error?) -> Void) {
        let tunnelProviderManager = tunnel.tunnelProvider
        let tunnelIndex = tunnel.index

        isDeletingTunnel = true

        tunnelProviderManager.removeFromPreferences { [weak self] (error) in
            defer { self?.isDeletingTunnel = false }
            guard (error != nil) else {
                completionHandler(error)
                return
            }
            if let s = self {
                for i in ((tunnelIndex + 1) ..< s.tunnels.count) {
                    s.tunnels[i].index = s.tunnels[i].index + 1
                }
                s.tunnels.remove(at: tunnelIndex)
            }
            completionHandler(nil)
        }
    }

    func numberOfTunnels() -> Int {
        return tunnels.count
    }

    func tunnel(at index: Int) -> TunnelContainer {
        return tunnels[index]
    }
}

extension NETunnelProviderProtocol {
    convenience init?(tunnelConfiguration: TunnelConfiguration) {
        assert(!tunnelConfiguration.interface.name.isEmpty)
        guard let serializedTunnelConfiguration = try? JSONEncoder().encode(tunnelConfiguration) else { return nil }

        self.init()

        let appId = Bundle.main.bundleIdentifier!
        let firstValidEndpoint = tunnelConfiguration.peers.first(where: { $0.endpoint != nil })?.endpoint

        providerBundleIdentifier = "\(appId).WireGuardNetworkExtension"
        providerConfiguration = [
            "tunnelConfiguration": serializedTunnelConfiguration
        ]
        serverAddress = firstValidEndpoint?.stringRepresentation() ?? "Unspecified"
        username = tunnelConfiguration.interface.name
    }

    func tunnelConfiguration() -> TunnelConfiguration? {
        guard let serializedTunnelConfiguration = providerConfiguration?["tunnelConfiguration"] as? Data else { return nil }
        return try? JSONDecoder().decode(TunnelConfiguration.self, from: serializedTunnelConfiguration)
    }
}
