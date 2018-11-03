// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import NetworkExtension
import os.log

protocol TunnelsManagerDelegate: class {
    func tunnelAdded(at: Int)
    func tunnelModified(at: Int)
    func tunnelMoved(at oldIndex: Int, to newIndex: Int)
    func tunnelRemoved(at: Int)
}

enum TunnelActivationError: Error {
    case noEndpoint
    case dnsResolutionFailed
    case tunnelActivationFailed
    case attemptingActivationWhenAnotherTunnelIsBusy(otherTunnelStatus: TunnelStatus)
    case attemptingActivationWhenTunnelIsNotInactive
    case attemptingDeactivationWhenTunnelIsInactive
}

enum TunnelManagementError: Error {
    case tunnelAlreadyExistsWithThatName
    case tunnelInvalidName
    case vpnSystemErrorOnAddTunnel
    case vpnSystemErrorOnModifyTunnel
    case vpnSystemErrorOnRemoveTunnel
}

class TunnelsManager {

    private var tunnels: [TunnelContainer]
    weak var delegate: TunnelsManagerDelegate? = nil

    private var isAddingTunnel: Bool = false
    private var isModifyingTunnel: Bool = false
    private var isDeletingTunnel: Bool = false

    init(tunnelProviders: [NETunnelProviderManager]) {
        self.tunnels = tunnelProviders.map { TunnelContainer(tunnel: $0) }.sorted { $0.name < $1.name }
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

    func add(tunnelConfiguration: TunnelConfiguration, completionHandler: @escaping (TunnelContainer?, TunnelManagementError?) -> Void) {
        let tunnelName = tunnelConfiguration.interface.name
        if tunnelName.isEmpty {
            completionHandler(nil, TunnelManagementError.tunnelAlreadyExistsWithThatName)
            return
        }
        
        if self.tunnels.contains(where: { $0.name == tunnelName }) {
            completionHandler(nil, TunnelManagementError.tunnelAlreadyExistsWithThatName)
            return
        }

        isAddingTunnel = true
        let tunnelProviderManager = NETunnelProviderManager()
        tunnelProviderManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration)
        tunnelProviderManager.localizedDescription = tunnelName
        tunnelProviderManager.isEnabled = true

        tunnelProviderManager.saveToPreferences { [weak self] (error) in
            defer { self?.isAddingTunnel = false }
            guard (error == nil) else {
                os_log("Add: Saving configuration failed: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                completionHandler(nil, TunnelManagementError.vpnSystemErrorOnAddTunnel)
                return
            }
            if let s = self {
                let tunnel = TunnelContainer(tunnel: tunnelProviderManager)
                s.tunnels.append(tunnel)
                s.tunnels.sort { $0.name < $1.name }
                s.delegate?.tunnelAdded(at: s.tunnels.firstIndex(of: tunnel)!)
                completionHandler(tunnel, nil)
            }
        }
    }

    func addMultiple(tunnelConfigurations: [TunnelConfiguration], completionHandler: @escaping (UInt) -> Void) {
        addMultiple(tunnelConfigurations: ArraySlice(tunnelConfigurations), numberSuccessful: 0, completionHandler: completionHandler)
    }

    private func addMultiple(tunnelConfigurations: ArraySlice<TunnelConfiguration>, numberSuccessful: UInt, completionHandler: @escaping (UInt) -> Void) {
        guard let head = tunnelConfigurations.first else {
            completionHandler(numberSuccessful)
            return
        }
        let tail = tunnelConfigurations.dropFirst()
        self.add(tunnelConfiguration: head) { [weak self, tail] (tunnel, error) in
            DispatchQueue.main.async {
                self?.addMultiple(tunnelConfigurations: tail, numberSuccessful: numberSuccessful + (error == nil ? 1 : 0), completionHandler: completionHandler)
            }
        }
    }

    func modify(tunnel: TunnelContainer, with tunnelConfiguration: TunnelConfiguration, completionHandler: @escaping (TunnelManagementError?) -> Void) {
        let tunnelName = tunnelConfiguration.interface.name
        if tunnelName.isEmpty {
            completionHandler(TunnelManagementError.tunnelAlreadyExistsWithThatName)
            return
        }

        isModifyingTunnel = true

        let tunnelProviderManager = tunnel.tunnelProvider
        let isNameChanged = (tunnelName != tunnelProviderManager.localizedDescription)
        var oldName: String? = nil
        if (isNameChanged) {
            if self.tunnels.contains(where: { $0.name == tunnelName }) {
                completionHandler(TunnelManagementError.tunnelAlreadyExistsWithThatName)
                return
            }
            oldName = tunnel.name
            tunnel.name = tunnelName
        }
        tunnelProviderManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration)
        tunnelProviderManager.localizedDescription = tunnelName
        tunnelProviderManager.isEnabled = true

        tunnelProviderManager.saveToPreferences { [weak self] (error) in
            defer { self?.isModifyingTunnel = false }
            guard (error == nil) else {
                os_log("Modify: Saving configuration failed: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                completionHandler(TunnelManagementError.vpnSystemErrorOnModifyTunnel)
                return
            }
            if let s = self {
                if (isNameChanged) {
                    let oldIndex = s.tunnels.firstIndex(of: tunnel)!
                    s.tunnels.sort { $0.name < $1.name }
                    let newIndex = s.tunnels.firstIndex(of: tunnel)!
                    s.delegate?.tunnelMoved(at: oldIndex, to: newIndex)
                }
                s.delegate?.tunnelModified(at: s.tunnels.firstIndex(of: tunnel)!)

                if (tunnel.status == .active || tunnel.status == .activating || tunnel.status == .reasserting) {
                    // Turn off the tunnel, and then turn it back on, so the changes are made effective
                    tunnel.beginRestart()
                }

                completionHandler(nil)
            }
        }
    }

    func remove(tunnel: TunnelContainer, completionHandler: @escaping (TunnelManagementError?) -> Void) {
        let tunnelProviderManager = tunnel.tunnelProvider

        isDeletingTunnel = true

        tunnelProviderManager.removeFromPreferences { [weak self] (error) in
            defer { self?.isDeletingTunnel = false }
            guard (error == nil) else {
                os_log("Remove: Saving configuration failed: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                completionHandler(TunnelManagementError.vpnSystemErrorOnRemoveTunnel)
                return
            }
            if let s = self {
                let index = s.tunnels.firstIndex(of: tunnel)!
                s.tunnels.remove(at: index)
                s.delegate?.tunnelRemoved(at: index)
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
            completionHandler(TunnelActivationError.attemptingActivationWhenTunnelIsNotInactive)
            return
        }
        for t in tunnels {
            if t.status != .inactive {
                completionHandler(TunnelActivationError.attemptingActivationWhenAnotherTunnelIsBusy(otherTunnelStatus: t.status))
                return
            }
        }
        tunnel.startActivation(completionHandler: completionHandler)
    }

    func startDeactivation(of tunnel: TunnelContainer, completionHandler: @escaping (Error?) -> Void) {
        if (tunnel.status == .inactive) {
            completionHandler(TunnelActivationError.attemptingDeactivationWhenTunnelIsInactive)
            return
        }
        tunnel.startDeactivation()
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
    fileprivate var statusObservationToken: AnyObject?

    private var dnsResolver: DNSResolver? = nil

    init(tunnel: NETunnelProviderManager) {
        self.name = tunnel.localizedDescription ?? "Unnamed"
        let status = TunnelStatus(from: tunnel.connection.status)
        self.status = status
        self.tunnelProvider = tunnel
        super.init()
        if (status != .inactive) {
            startObservingTunnelStatus()
        }
    }

    func tunnelConfiguration() -> TunnelConfiguration? {
        return (tunnelProvider.protocolConfiguration as! NETunnelProviderProtocol).tunnelConfiguration()
    }

    fileprivate func startActivation(completionHandler: @escaping (Error?) -> Void) {
        assert(status == .inactive || status == .restarting)
        assert(self.dnsResolver == nil)

        guard let tunnelConfiguration = tunnelConfiguration() else { fatalError() }
        let endpoints = tunnelConfiguration.peers.map { $0.endpoint }

        // Ensure there's a tunner server address we can give to iOS
        guard (endpoints.contains(where: { $0 != nil })) else {
            DispatchQueue.main.async { [weak self] in
                self?.status = .inactive
                completionHandler(TunnelActivationError.noEndpoint)
            }
            return
        }

        // Resolve DNS and start the tunnel
        let dnsResolver = DNSResolver(endpoints: endpoints)
        let resolvedEndpoints = dnsResolver.resolveWithoutNetworkRequests()
        if let resolvedEndpoints = resolvedEndpoints {
            // If we don't have to make a DNS network request, we never
            // change the status to .resolvingEndpointDomains
            startActivation(tunnelConfiguration: tunnelConfiguration,
                            resolvedEndpoints: resolvedEndpoints,
                            completionHandler: completionHandler)
        } else {
            status = .resolvingEndpointDomains
            self.dnsResolver = dnsResolver
            dnsResolver.resolve { [weak self] resolvedEndpoints in
                guard let s = self else { return }
                assert(s.status == .resolvingEndpointDomains)
                s.dnsResolver = nil
                guard let resolvedEndpoints = resolvedEndpoints else {
                    s.status = .inactive
                    completionHandler(TunnelActivationError.dnsResolutionFailed)
                    return
                }
                s.startActivation(tunnelConfiguration: tunnelConfiguration,
                                resolvedEndpoints: resolvedEndpoints,
                                completionHandler: completionHandler)
            }
        }
    }

    fileprivate func startActivation(recursionCount: UInt = 0,
                                     lastError: Error? = nil,
                                     tunnelConfiguration: TunnelConfiguration,
                                     resolvedEndpoints: [Endpoint?],
                                     completionHandler: @escaping (Error?) -> Void) {
        if (recursionCount >= 8) {
            os_log("startActivation: Failed after 8 attempts. Giving up with %{public}@", log: OSLog.default, type: .error, "\(lastError!)")
            completionHandler(TunnelActivationError.tunnelActivationFailed)
            return
        }

        // resolvedEndpoints should contain only IP addresses, not any named endpoints
        assert(resolvedEndpoints.allSatisfy { (resolvedEndpoint) in
            guard let resolvedEndpoint = resolvedEndpoint else { return true }
            switch (resolvedEndpoint.host) {
            case .ipv4(_): return true
            case .ipv6(_): return true
            case .name(_, _): return false
            }
        })

        os_log("startActivation: Entering", log: OSLog.default, type: .debug)

        guard (tunnelProvider.isEnabled) else {
            // In case the tunnel had gotten disabled, re-enable and save it,
            // then call this function again.
            os_log("startActivation: Tunnel is disabled. Re-enabling and saving", log: OSLog.default, type: .info)
            tunnelProvider.isEnabled = true
            tunnelProvider.saveToPreferences { [weak self] (error) in
                if (error != nil) {
                    os_log("Error saving tunnel after re-enabling: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                    completionHandler(error)
                    return
                }
                os_log("startActivation: Tunnel saved after re-enabling", log: OSLog.default, type: .info)
                os_log("startActivation: Invoking startActivation", log: OSLog.default, type: .debug)
                self?.startActivation(recursionCount: recursionCount + 1, lastError: NEVPNError(NEVPNError.configurationUnknown), tunnelConfiguration: tunnelConfiguration, resolvedEndpoints: resolvedEndpoints, completionHandler: completionHandler)
            }
            return
        }

        // Start the tunnel
        let session = (tunnelProvider.connection as! NETunnelProviderSession)
        do {
            os_log("startActivation: Generating options", log: OSLog.default, type: .debug)
            let tunnelOptions = PacketTunnelOptionsGenerator.generateOptions(
                from: tunnelConfiguration, withResolvedEndpoints: resolvedEndpoints)
            os_log("startActivation: Starting tunnel", log: OSLog.default, type: .debug)
            try session.startTunnel(options: tunnelOptions)
            os_log("startActivation: Success", log: OSLog.default, type: .debug)
            startObservingTunnelStatus()
            completionHandler(nil)
        } catch (let error) {
            os_log("startActivation: Error starting tunnel. Examining error", log: OSLog.default, type: .debug)
            guard let vpnError = error as? NEVPNError else {
                os_log("Failed to activate tunnel: %{public}@", log: OSLog.default, type: .debug, "\(error)")
                status = .inactive
                completionHandler(error)
                return
            }
            guard (vpnError.code == NEVPNError.configurationInvalid || vpnError.code == NEVPNError.configurationStale) else {
                    os_log("Failed to activate tunnel: %{public}@", log: OSLog.default, type: .debug, "\(error)")
                    status = .inactive
                    completionHandler(error)
                    return
            }
            assert(vpnError.code == NEVPNError.configurationInvalid || vpnError.code == NEVPNError.configurationStale)
            os_log("startActivation: Error says: %{public}@", log: OSLog.default, type: .debug,
                   vpnError.code == NEVPNError.configurationInvalid ? "Configuration invalid" : "Configuration stale")
            os_log("startActivation: Will reload tunnel and then try to start it. ", log: OSLog.default, type: .info)
            tunnelProvider.loadFromPreferences { [weak self] (error) in
                if (error != nil) {
                    os_log("Failed to activate tunnel: %{public}@", log: OSLog.default, type: .debug, "\(error!)")
                    self?.status = .inactive
                    completionHandler(error)
                    return
                }
                os_log("startActivation: Tunnel reloaded", log: OSLog.default, type: .info)
                os_log("startActivation: Invoking startActivation", log: OSLog.default, type: .debug)
                self?.startActivation(recursionCount: recursionCount + 1, lastError: vpnError, tunnelConfiguration: tunnelConfiguration, resolvedEndpoints: resolvedEndpoints, completionHandler: completionHandler)
            }
        }
    }

    fileprivate func startDeactivation() {
        assert(status == .active)
        assert(statusObservationToken != nil)
        let session = (tunnelProvider.connection as! NETunnelProviderSession)
        session.stopTunnel()
    }

    fileprivate func beginRestart() {
        assert(status == .active || status == .activating || status == .reasserting)
        assert(statusObservationToken != nil)
        status = .restarting
        let session = (tunnelProvider.connection as! NETunnelProviderSession)
        session.stopTunnel()
    }

    private func startObservingTunnelStatus() {
        if (statusObservationToken != nil) { return }
        let connection = tunnelProvider.connection
        statusObservationToken = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: connection,
            queue: nil) { [weak self] (_) in
                guard let s = self else { return }
                if ((s.status == .restarting) && (connection.status == .disconnected || connection.status == .disconnecting)) {
                    // Don't change s.status when disconnecting for a restart
                    if (connection.status == .disconnected) {
                        self?.startActivation(completionHandler: { _ in })
                    }
                    return
                }
                if (s.status == .resolvingEndpointDomains && connection.status == .disconnected) {
                    // Don't change to .inactive if we're still resolving endpoints
                    assert(false)
                    return
                }
                s.status = TunnelStatus(from: connection.status)
                if (s.status == .inactive) {
                    s.stopObservingTunnelStatus()
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
    case reasserting // Not a possible state at present

    case restarting // Restarting tunnel (done after saving modifications to an active tunnel)
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
