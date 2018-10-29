// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import Foundation
import NetworkExtension
import os.log

protocol TunnelsManagerDelegate: class {
    func tunnelAdded(at: Int)
    func tunnelModified(at: Int)
    func tunnelsChanged()
    func tunnelRemoved(at: Int)
}

enum TunnelsManagerError: Error {
    case dnsResolutionFailed
    case tunnelOperationFailed
    case attemptingActivationWhenAnotherTunnelIsActive
    case attemptingActivationWhenTunnelIsNotInactive
    case attemptingDeactivationWhenTunnelIsInactive
}

class TunnelsManager {

    var tunnels: [TunnelContainer]
    weak var delegate: TunnelsManagerDelegate? = nil

    private var isAddingTunnel: Bool = false
    private var isModifyingTunnel: Bool = false
    private var isDeletingTunnel: Bool = false

    private var currentTunnel: TunnelContainer?
    private var currentTunnelStatusObservationToken: AnyObject?

    init(tunnelProviders: [NETunnelProviderManager]) {
        var tunnels = tunnelProviders.map { TunnelContainer(tunnel: $0, index: 0) }
        tunnels.sort { $0.name < $1.name }
        var currentTunnel: TunnelContainer? = nil
        for i in 0 ..< tunnels.count {
            let tunnel = tunnels[i]
            tunnel.index = i
            if (tunnel.status != .inactive) {
                currentTunnel = tunnel
            }
        }
        self.tunnels = tunnels
        if let currentTunnel = currentTunnel {
            setCurrentTunnel(tunnel: currentTunnel)
        }
    }

    static func create(completionHandler: @escaping (TunnelsManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
            if let error = error {
                os_log("Failed to load tunnel provider managers: %{public}@", log: OSLog.default, type: .debug, "\(error)")
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
        if (isNameChanged) {
            tunnel.name = tunnelName
        }
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
            guard (error == nil) else {
                completionHandler(error)
                return
            }
            if let s = self {
                for i in ((tunnelIndex + 1) ..< s.tunnels.count) {
                    s.tunnels[i].index = s.tunnels[i].index + 1
                }
                s.tunnels.remove(at: tunnelIndex)
                s.delegate?.tunnelRemoved(at: tunnelIndex)
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

    func startActivation(of tunnel: TunnelContainer, completionHandler: @escaping (Error?) -> Void) {
        guard (tunnel.status == .inactive) else {
            completionHandler(TunnelsManagerError.attemptingActivationWhenTunnelIsNotInactive)
            return
        }
        guard (currentTunnel == nil) else {
            completionHandler(TunnelsManagerError.attemptingActivationWhenAnotherTunnelIsActive)
            return
        }
        tunnel.startActivation(completionHandler: completionHandler)
        setCurrentTunnel(tunnel: tunnel)
    }

    func startDeactivation(of tunnel: TunnelContainer, completionHandler: @escaping (Error?) -> Void) {
        if (tunnel.status == .inactive) {
            completionHandler(TunnelsManagerError.attemptingDeactivationWhenTunnelIsInactive)
            return
        }
        assert(tunnel.index == currentTunnel!.index)

        tunnel.startDeactivation()
    }

    private func setCurrentTunnel(tunnel: TunnelContainer) {
        currentTunnel = tunnel
        currentTunnelStatusObservationToken = tunnel.observe(\.status) { [weak self] (tunnel, change) in
            guard let s = self else { return }
            if (tunnel.status == .inactive) {
                s.currentTunnel = nil
                s.currentTunnelStatusObservationToken = nil
            }
        }
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
            "tunnelConfiguration": serializedTunnelConfiguration,
            "tunnelConfigurationVersion": 1
        ]
        serverAddress = firstValidEndpoint?.stringRepresentation() ?? "Unspecified"
        username = tunnelConfiguration.interface.name
    }

    func tunnelConfiguration() -> TunnelConfiguration? {
        guard let serializedTunnelConfiguration = providerConfiguration?["tunnelConfiguration"] as? Data else { return nil }
        return try? JSONDecoder().decode(TunnelConfiguration.self, from: serializedTunnelConfiguration)
    }
}

class TunnelContainer: NSObject {
    @objc dynamic var name: String
    @objc dynamic var status: TunnelStatus

    fileprivate let tunnelProvider: NETunnelProviderManager
    fileprivate var index: Int
    fileprivate var statusObservationToken: AnyObject?

    private var dnsResolver: DNSResolver? = nil

    init(tunnel: NETunnelProviderManager, index: Int) {
        self.name = tunnel.localizedDescription ?? "Unnamed"
        let status = TunnelStatus(from: tunnel.connection.status)
        self.status = status
        self.tunnelProvider = tunnel
        self.index = index
        super.init()
        if (status != .inactive) {
            startObservingTunnelStatus()
        }
    }

    func tunnelConfiguration() -> TunnelConfiguration? {
        return (tunnelProvider.protocolConfiguration as! NETunnelProviderProtocol).tunnelConfiguration()
    }

    fileprivate func startActivation(completionHandler: @escaping (Error?) -> Void) {
        assert(status == .inactive)
        guard let tunnelConfiguration = tunnelConfiguration() else { fatalError() }
        let endpoints = tunnelConfiguration.peers.map { $0.endpoint }
        let dnsResolver = DNSResolver(endpoints: endpoints)
        assert(self.dnsResolver == nil)
        if let endpoints = dnsResolver.resolveWithoutNetworkRequests() {
            self.tunnelProvider.loadFromPreferences { [weak self] (error) in
                guard let s = self else { return }
                s.startObservingTunnelStatus()
                let session = (s.tunnelProvider.connection as! NETunnelProviderSession)
                do {
                    let tunnelOptions = PacketTunnelOptionsGenerator.generateOptions(
                        from: tunnelConfiguration, withResolvedEndpoints: endpoints)
                    try session.startTunnel(options: tunnelOptions)
                } catch (let error) {
                    os_log("Failed to activate tunnel: %{public}@", log: OSLog.default, type: .debug, "\(error)")
                    completionHandler(error)
                }
            }
        } else {
            self.dnsResolver = dnsResolver
            status = .resolvingEndpointDomains
            dnsResolver.resolve { [weak self] endpoints in
                guard let s = self else { return }
                assert(s.status == .resolvingEndpointDomains)
                s.dnsResolver = nil
                guard let endpoints = endpoints else {
                    completionHandler(TunnelsManagerError.dnsResolutionFailed)
                    s.status = .inactive
                    return
                }
                s.tunnelProvider.loadFromPreferences { [weak s] (error) in
                    guard let s = s else { return }
                    s.startObservingTunnelStatus()
                    let session = (s.tunnelProvider.connection as! NETunnelProviderSession)
                    do {
                        let tunnelOptions = PacketTunnelOptionsGenerator.generateOptions(
                            from: tunnelConfiguration, withResolvedEndpoints: endpoints)
                        try session.startTunnel(options: tunnelOptions)
                    } catch (let error) {
                        os_log("Failed to activate tunnel: %{public}@", log: OSLog.default, type: .debug, "\(error)")
                        completionHandler(error)
                    }
                }
            }
        }
    }

    fileprivate func startDeactivation() {
        assert(status == .active)
        assert(statusObservationToken != nil)
        let session = (tunnelProvider.connection as! NETunnelProviderSession)
        session.stopTunnel()
    }

    private func startObservingTunnelStatus() {
        let connection = tunnelProvider.connection
        statusObservationToken = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: connection,
            queue: nil) { [weak self] (_) in
                let status = TunnelStatus(from: connection.status)
                if let s = self {
                    s.status = status
                    if (status == .inactive) {
                        s.stopObservingTunnelStatus()
                    }
                }
        }
    }

    private func stopObservingTunnelStatus() {
        DispatchQueue.main.async { [weak self] in
            self?.statusObservationToken = nil
        }
    }
}

@objc enum TunnelStatus: Int {
    case inactive
    case activating
    case active
    case deactivating
    case reasserting // On editing an active tunnel, the tunnel shall deactive and then activate

    case resolvingEndpointDomains // DNS resolution in progress

    init(from vpnStatus: NEVPNStatus) {
        switch (vpnStatus) {
        case .connected:
            self = .active
        case .connecting:
            self = .activating
        case .disconnected:
            self = .inactive
        case .disconnecting:
            self = .deactivating
        case .reasserting:
            self = .reasserting
        case .invalid:
            self = .inactive
        }
    }
}
