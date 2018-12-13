// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import NetworkExtension
import os.log

protocol TunnelsManagerListDelegate: class {
    func tunnelAdded(at index: Int)
    func tunnelModified(at index: Int)
    func tunnelMoved(from oldIndex: Int, to newIndex: Int)
    func tunnelRemoved(at index: Int)
}

protocol TunnelsManagerActivationDelegate: class {
    func tunnelActivationFailed(tunnel: TunnelContainer, error: TunnelsManagerError)
}

enum TunnelsManagerError: WireGuardAppError {
    // Tunnels list management
    case tunnelNameEmpty
    case tunnelAlreadyExistsWithThatName
    case vpnSystemErrorOnListingTunnels
    case vpnSystemErrorOnAddTunnel
    case vpnSystemErrorOnModifyTunnel
    case vpnSystemErrorOnRemoveTunnel

    // Tunnel activation
    case attemptingActivationWhenTunnelIsNotInactive
    case attemptingActivationWhenAnotherTunnelIsOperational(otherTunnelName: String)
    case tunnelActivationAttemptFailed // startTunnel() throwed
    case tunnelActivationFailedInternalError // startTunnel() succeeded, but activation failed
    case tunnelActivationFailedNoInternetConnection // startTunnel() succeeded, but activation failed since no internet

    //swiftlint:disable:next cyclomatic_complexity
    func alertText() -> AlertText {
        switch self {
        case .tunnelNameEmpty:
            return ("No name provided", "Can't create tunnel with an empty name")
        case .tunnelAlreadyExistsWithThatName:
            return ("Name already exists", "A tunnel with that name already exists")
        case .vpnSystemErrorOnListingTunnels:
            return ("Unable to list tunnels", "Internal error")
        case .vpnSystemErrorOnAddTunnel:
            return ("Unable to create tunnel", "Internal error")
        case .vpnSystemErrorOnModifyTunnel:
            return ("Unable to modify tunnel", "Internal error")
        case .vpnSystemErrorOnRemoveTunnel:
            return ("Unable to remove tunnel", "Internal error")
        case .attemptingActivationWhenTunnelIsNotInactive:
            return ("Activation failure", "The tunnel is already active or in the process of being activated")
        case .attemptingActivationWhenAnotherTunnelIsOperational(let otherTunnelName):
            return ("Activation failure", "Please disconnect '\(otherTunnelName)' before enabling this tunnel.")
        case .tunnelActivationAttemptFailed:
            return ("Activation failure", "The tunnel could not be activated due to an internal error")
        case .tunnelActivationFailedInternalError:
            return ("Activation failure", "The tunnel could not be activated due to an internal error")
        case .tunnelActivationFailedNoInternetConnection:
            return ("Activation failure", "No internet connection")
        }
    }
}

class TunnelsManager {

    private var tunnels: [TunnelContainer]
    weak var tunnelsListDelegate: TunnelsManagerListDelegate?
    weak var activationDelegate: TunnelsManagerActivationDelegate?
    private var statusObservationToken: AnyObject?

    var tunnelBeingActivated: TunnelContainer?

    init(tunnelProviders: [NETunnelProviderManager]) {
        self.tunnels = tunnelProviders.map { TunnelContainer(tunnel: $0) }.sorted { $0.name < $1.name }
        self.startObservingTunnelStatuses()
    }

    static func create(completionHandler: @escaping (WireGuardResult<TunnelsManager>) -> Void) {
        #if targetEnvironment(simulator)
        // NETunnelProviderManager APIs don't work on the simulator
        completionHandler(.success(TunnelsManager(tunnelProviders: [])))
        #else
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                os_log("Failed to load tunnel provider managers: %{public}@", log: OSLog.default, type: .debug, "\(error)")
                completionHandler(.failure(TunnelsManagerError.vpnSystemErrorOnListingTunnels))
                return
            }
            completionHandler(.success(TunnelsManager(tunnelProviders: managers ?? [])))
        }
        #endif
    }

    func add(tunnelConfiguration: TunnelConfiguration,
             activateOnDemandSetting: ActivateOnDemandSetting = ActivateOnDemandSetting.defaultSetting,
             completionHandler: @escaping (WireGuardResult<TunnelContainer>) -> Void) {
        let tunnelName = tunnelConfiguration.interface.name
        if tunnelName.isEmpty {
            completionHandler(.failure(TunnelsManagerError.tunnelNameEmpty))
            return
        }

        if self.tunnels.contains(where: { $0.name == tunnelName }) {
            completionHandler(.failure(TunnelsManagerError.tunnelAlreadyExistsWithThatName))
            return
        }

        let tunnelProviderManager = NETunnelProviderManager()
        tunnelProviderManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration)
        tunnelProviderManager.localizedDescription = tunnelName
        tunnelProviderManager.isEnabled = true

        activateOnDemandSetting.apply(on: tunnelProviderManager)

        tunnelProviderManager.saveToPreferences { [weak self] error in
            guard error == nil else {
                os_log("Add: Saving configuration failed: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                completionHandler(.failure(TunnelsManagerError.vpnSystemErrorOnAddTunnel))
                return
            }
            if let self = self {
                let tunnel = TunnelContainer(tunnel: tunnelProviderManager)
                self.tunnels.append(tunnel)
                self.tunnels.sort { $0.name < $1.name }
                self.tunnelsListDelegate?.tunnelAdded(at: self.tunnels.firstIndex(of: tunnel)!)
                completionHandler(.success(tunnel))
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
        self.add(tunnelConfiguration: head) { [weak self, tail] result in
            DispatchQueue.main.async {
                self?.addMultiple(tunnelConfigurations: tail, numberSuccessful: numberSuccessful + (result.isSuccess ? 1 : 0), completionHandler: completionHandler)
            }
        }
    }

    func modify(tunnel: TunnelContainer, tunnelConfiguration: TunnelConfiguration,
                activateOnDemandSetting: ActivateOnDemandSetting, completionHandler: @escaping (TunnelsManagerError?) -> Void) {
        let tunnelName = tunnelConfiguration.interface.name
        if tunnelName.isEmpty {
            completionHandler(TunnelsManagerError.tunnelNameEmpty)
            return
        }

        let tunnelProviderManager = tunnel.tunnelProvider
        let isNameChanged = (tunnelName != tunnelProviderManager.localizedDescription)
        if isNameChanged {
            if self.tunnels.contains(where: { $0.name == tunnelName }) {
                completionHandler(TunnelsManagerError.tunnelAlreadyExistsWithThatName)
                return
            }
            tunnel.name = tunnelName
        }
        tunnelProviderManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration)
        tunnelProviderManager.localizedDescription = tunnelName
        tunnelProviderManager.isEnabled = true

        let isActivatingOnDemand = (!tunnelProviderManager.isOnDemandEnabled && activateOnDemandSetting.isActivateOnDemandEnabled)
        activateOnDemandSetting.apply(on: tunnelProviderManager)

        tunnelProviderManager.saveToPreferences { [weak self] error in
            guard error == nil else {
                os_log("Modify: Saving configuration failed: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                completionHandler(TunnelsManagerError.vpnSystemErrorOnModifyTunnel)
                return
            }
            if let self = self {
                if isNameChanged {
                    let oldIndex = self.tunnels.firstIndex(of: tunnel)!
                    self.tunnels.sort { $0.name < $1.name }
                    let newIndex = self.tunnels.firstIndex(of: tunnel)!
                    self.tunnelsListDelegate?.tunnelMoved(from: oldIndex, to: newIndex)
                }
                self.tunnelsListDelegate?.tunnelModified(at: self.tunnels.firstIndex(of: tunnel)!)

                if tunnel.status == .active || tunnel.status == .activating || tunnel.status == .reasserting {
                    // Turn off the tunnel, and then turn it back on, so the changes are made effective
                    tunnel.status = .restarting
                    (tunnel.tunnelProvider.connection as? NETunnelProviderSession)?.stopTunnel()
                }

                if isActivatingOnDemand {
                    // Reload tunnel after saving.
                    // Without this, the tunnel stopes getting updates on the tunnel status from iOS.
                    tunnelProviderManager.loadFromPreferences { error in
                        tunnel.isActivateOnDemandEnabled = tunnelProviderManager.isOnDemandEnabled
                        guard error == nil else {
                            os_log("Modify: Re-loading after saving configuration failed: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                            completionHandler(TunnelsManagerError.vpnSystemErrorOnModifyTunnel)
                            return
                        }
                        completionHandler(nil)
                    }
                } else {
                    completionHandler(nil)
                }
            }
        }
    }

    func remove(tunnel: TunnelContainer, completionHandler: @escaping (TunnelsManagerError?) -> Void) {
        let tunnelProviderManager = tunnel.tunnelProvider

        tunnelProviderManager.removeFromPreferences { [weak self] error in
            guard error == nil else {
                os_log("Remove: Saving configuration failed: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                completionHandler(TunnelsManagerError.vpnSystemErrorOnRemoveTunnel)
                return
            }
            if let self = self {
                let index = self.tunnels.firstIndex(of: tunnel)!
                self.tunnels.remove(at: index)
                self.tunnelsListDelegate?.tunnelRemoved(at: index)
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

    func tunnel(named tunnelName: String) -> TunnelContainer? {
        return self.tunnels.first { $0.name == tunnelName }
    }

    func startActivation(of tunnel: TunnelContainer, completionHandler: @escaping (TunnelsManagerError?) -> Void) {
        guard tunnels.contains(tunnel) else { return } // Ensure it's not deleted
        guard tunnel.status == .inactive else {
            completionHandler(TunnelsManagerError.attemptingActivationWhenTunnelIsNotInactive)
            return
        }

        if let tunnelInOperation = tunnels.first(where: { $0.status != .inactive }) {
            completionHandler(TunnelsManagerError.attemptingActivationWhenAnotherTunnelIsOperational(otherTunnelName: tunnelInOperation.name))
            return
        }

        tunnelBeingActivated = tunnel
        tunnel.startActivation(completionHandler: completionHandler)
    }

    func startDeactivation(of tunnel: TunnelContainer) {
        if tunnel.status == .inactive || tunnel.status == .deactivating {
            return
        }
        tunnel.startDeactivation()
    }

    func refreshStatuses() {
        tunnels.forEach { $0.refreshStatus() }
    }

    private func startObservingTunnelStatuses() {
        guard statusObservationToken == nil else { return }

        statusObservationToken = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: OperationQueue.main) { [weak self] statusChangeNotification in
            guard let self = self else { return }
            guard let session = statusChangeNotification.object as? NETunnelProviderSession else { return }
            guard let tunnelProvider = session.manager as? NETunnelProviderManager else { return }
            guard let tunnel = self.tunnels.first(where: { $0.tunnelProvider == tunnelProvider }) else { return }

            os_log("Tunnel '%{public}@' connection status changed to '%{public}@'",
                   log: OSLog.default, type: .debug, tunnel.name, "\(tunnel.tunnelProvider.connection.status)")

            // In case our attempt to start the tunnel, didn't succeed
            if tunnel == self.tunnelBeingActivated {
                if session.status == .disconnected {
                    if InternetReachability.currentStatus() == .notReachable {
                        let error = TunnelsManagerError.tunnelActivationFailedNoInternetConnection
                        self.activationDelegate?.tunnelActivationFailed(tunnel: tunnel, error: error)
                    }
                    self.tunnelBeingActivated = nil
                } else if session.status == .connected {
                    self.tunnelBeingActivated = nil
                }
            }

            // In case we're restarting the tunnel
            if (tunnel.status == .restarting) && (session.status == .disconnected || session.status == .disconnecting) {
                // Don't change tunnel.status when disconnecting for a restart
                if session.status == .disconnected {
                    self.tunnelBeingActivated = tunnel
                    tunnel.startActivation { _ in }
                }
                return
            }

            tunnel.refreshStatus()
        }
    }

    deinit {
        if let statusObservationToken = self.statusObservationToken {
            NotificationCenter.default.removeObserver(statusObservationToken)
        }
    }
}

class TunnelContainer: NSObject {
    @objc dynamic var name: String
    @objc dynamic var status: TunnelStatus

    @objc dynamic var isActivateOnDemandEnabled: Bool

    var isAttemptingActivation: Bool = false
    var onActivationCommitted: ((Bool) -> Void)?
    var onDeactivationComplete: (() -> Void)?

    fileprivate let tunnelProvider: NETunnelProviderManager
    private var lastTunnelConnectionStatus: NEVPNStatus?

    init(tunnel: NETunnelProviderManager) {
        self.name = tunnel.localizedDescription ?? "Unnamed"
        let status = TunnelStatus(from: tunnel.connection.status)
        self.status = status
        self.isActivateOnDemandEnabled = tunnel.isOnDemandEnabled
        self.tunnelProvider = tunnel
        super.init()
    }

    func tunnelConfiguration() -> TunnelConfiguration? {
        return (tunnelProvider.protocolConfiguration as? NETunnelProviderProtocol)?.tunnelConfiguration()
    }

    func activateOnDemandSetting() -> ActivateOnDemandSetting {
        return ActivateOnDemandSetting(from: tunnelProvider)
    }

    func refreshStatus() {
        let status = TunnelStatus(from: self.tunnelProvider.connection.status)
        self.status = status
        self.isActivateOnDemandEnabled = self.tunnelProvider.isOnDemandEnabled
    }

    fileprivate func startActivation(completionHandler: @escaping (TunnelsManagerError?) -> Void) {
        assert(status == .inactive || status == .restarting)

        guard let tunnelConfiguration = tunnelConfiguration() else { fatalError() }

        startActivation(tunnelConfiguration: tunnelConfiguration, completionHandler: completionHandler)
    }

    fileprivate func startActivation(recursionCount: UInt = 0,
                                     lastError: Error? = nil,
                                     tunnelConfiguration: TunnelConfiguration,
                                     completionHandler: @escaping (TunnelsManagerError?) -> Void) {
        if recursionCount >= 8 {
            os_log("startActivation: Failed after 8 attempts. Giving up with %{public}@", log: OSLog.default, type: .error, "\(lastError!)")
            completionHandler(TunnelsManagerError.tunnelActivationAttemptFailed)
            return
        }

        os_log("startActivation: Entering (tunnel: %{public}@)", log: OSLog.default, type: .debug, self.name)

        guard tunnelProvider.isEnabled else {
            // In case the tunnel had gotten disabled, re-enable and save it,
            // then call this function again.
            os_log("startActivation: Tunnel is disabled. Re-enabling and saving", log: OSLog.default, type: .info)
            tunnelProvider.isEnabled = true
            tunnelProvider.saveToPreferences { [weak self] error in
                if error != nil {
                    os_log("Error saving tunnel after re-enabling: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                    completionHandler(TunnelsManagerError.tunnelActivationAttemptFailed)
                    return
                }
                os_log("startActivation: Tunnel saved after re-enabling", log: OSLog.default, type: .info)
                os_log("startActivation: Invoking startActivation", log: OSLog.default, type: .debug)
                self?.startActivation(recursionCount: recursionCount + 1, lastError: NEVPNError(NEVPNError.configurationUnknown),
                                      tunnelConfiguration: tunnelConfiguration, completionHandler: completionHandler)
            }
            return
        }

        // Start the tunnel
        do {
            os_log("startActivation: Starting tunnel", log: OSLog.default, type: .debug)
            try (tunnelProvider.connection as? NETunnelProviderSession)?.startTunnel()
            os_log("startActivation: Success", log: OSLog.default, type: .debug)
            completionHandler(nil)
        } catch let error {
            guard let vpnError = error as? NEVPNError else {
                os_log("Failed to activate tunnel: Error: %{public}@", log: OSLog.default, type: .debug, "\(error)")
                status = .inactive
                completionHandler(TunnelsManagerError.tunnelActivationAttemptFailed)
                return
            }
            guard vpnError.code == NEVPNError.configurationInvalid || vpnError.code == NEVPNError.configurationStale else {
                os_log("Failed to activate tunnel: VPN Error: %{public}@", log: OSLog.default, type: .debug, "\(error)")
                status = .inactive
                completionHandler(TunnelsManagerError.tunnelActivationAttemptFailed)
                return
            }
            os_log("startActivation: Will reload tunnel and then try to start it. ", log: OSLog.default, type: .info)
            tunnelProvider.loadFromPreferences { [weak self] error in
                if error != nil {
                    os_log("startActivation: Error reloading tunnel: %{public}@", log: OSLog.default, type: .debug, "\(error!)")
                    self?.status = .inactive
                    completionHandler(TunnelsManagerError.tunnelActivationAttemptFailed)
                    return
                }
                os_log("startActivation: Tunnel reloaded", log: OSLog.default, type: .info)
                os_log("startActivation: Invoking startActivation", log: OSLog.default, type: .debug)
                self?.startActivation(recursionCount: recursionCount + 1, lastError: vpnError, tunnelConfiguration: tunnelConfiguration, completionHandler: completionHandler)
            }
        }
    }

    fileprivate func startDeactivation() {
        (tunnelProvider.connection as? NETunnelProviderSession)?.stopTunnel()
    }
}

@objc enum TunnelStatus: Int {
    case inactive
    case activating
    case active
    case deactivating
    case reasserting // Not a possible state at present

    case restarting // Restarting tunnel (done after saving modifications to an active tunnel)

    init(from vpnStatus: NEVPNStatus) {
        switch vpnStatus {
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

extension TunnelStatus: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .inactive: return "inactive"
        case .activating: return "activating"
        case .active: return "active"
        case .deactivating: return "deactivating"
        case .reasserting: return "reasserting"
        case .restarting: return "restarting"
        }
    }
}

extension NEVPNStatus: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .connected: return "connected"
        case .connecting: return "connecting"
        case .disconnected: return "disconnected"
        case .disconnecting: return "disconnecting"
        case .reasserting: return "reasserting"
        case .invalid: return "invalid"
        }
    }
}
