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
    func tunnelActivationAttemptFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationAttemptError) // startTunnel wasn't called or failed
    func tunnelActivationAttemptSucceeded(tunnel: TunnelContainer) // startTunnel succeeded
    func tunnelActivationFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationError) // status didn't change to connected
    func tunnelActivationSucceeded(tunnel: TunnelContainer) // status changed to connected
}

enum TunnelsManagerActivationAttemptError: WireGuardAppError {
    case tunnelIsNotInactive
    case anotherTunnelIsOperational(otherTunnelName: String)
    case failedWhileStarting // startTunnel() throwed
    case failedWhileSaving // save config after re-enabling throwed
    case failedWhileLoading // reloading config throwed
    case failedBecauseOfTooManyErrors // recursion limit reached

    func alertText() -> AlertText {
        switch self {
        case .tunnelIsNotInactive:
            return ("Activation failure", "The tunnel is already active or in the process of being activated")
        case .anotherTunnelIsOperational(let otherTunnelName):
            return ("Activation failure", "Please disconnect '\(otherTunnelName)' before enabling this tunnel.")
        case .failedWhileStarting, .failedWhileSaving, .failedWhileLoading, .failedBecauseOfTooManyErrors:
            return ("Activation failure", "The tunnel could not be activated due to an internal error")
        }
    }
}

enum TunnelsManagerActivationError: WireGuardAppError {
    case activationFailed
    func alertText() -> AlertText {
        return ("Activation failure", "The tunnel could not be activated")
    }
}

enum TunnelsManagerError: WireGuardAppError {
    // Tunnels list management
    case tunnelNameEmpty
    case tunnelAlreadyExistsWithThatName
    case systemErrorOnListingTunnels
    case systemErrorOnAddTunnel
    case systemErrorOnModifyTunnel
    case systemErrorOnRemoveTunnel

    func alertText() -> AlertText {
        switch self {
        case .tunnelNameEmpty:
            return ("No name provided", "Can't create tunnel with an empty name")
        case .tunnelAlreadyExistsWithThatName:
            return ("Name already exists", "A tunnel with that name already exists")
        case .systemErrorOnListingTunnels:
            return ("Unable to list tunnels", "Internal error")
        case .systemErrorOnAddTunnel:
            return ("Unable to create tunnel", "Internal error")
        case .systemErrorOnModifyTunnel:
            return ("Unable to modify tunnel", "Internal error")
        case .systemErrorOnRemoveTunnel:
            return ("Unable to remove tunnel", "Internal error")
        }
    }
}

class TunnelsManager {

    private var tunnels: [TunnelContainer]
    weak var tunnelsListDelegate: TunnelsManagerListDelegate?
    weak var activationDelegate: TunnelsManagerActivationDelegate?
    private var statusObservationToken: AnyObject?

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
                wg_log(.error, message: "Failed to load tunnel provider managers: \(error)")
                completionHandler(.failure(TunnelsManagerError.systemErrorOnListingTunnels))
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
                wg_log(.error, message: "Add: Saving configuration failed: \(error!)")
                completionHandler(.failure(TunnelsManagerError.systemErrorOnAddTunnel))
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
                wg_log(.error, message: "Modify: Saving configuration failed: \(error!)")
                completionHandler(TunnelsManagerError.systemErrorOnModifyTunnel)
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
                            wg_log(.error, message: "Modify: Re-loading after saving configuration failed: \(error!)")
                            completionHandler(TunnelsManagerError.systemErrorOnModifyTunnel)
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
                wg_log(.error, message: "Remove: Saving configuration failed: \(error!)")
                completionHandler(TunnelsManagerError.systemErrorOnRemoveTunnel)
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

    func startActivation(of tunnel: TunnelContainer) {
        guard tunnels.contains(tunnel) else { return } // Ensure it's not deleted
        guard tunnel.status == .inactive else {
            self.activationDelegate?.tunnelActivationAttemptFailed(tunnel: tunnel, error: .tunnelIsNotInactive)
            return
        }

        if let alreadyWaitingTunnel = tunnels.first(where: { $0.status == .waiting }) {
            alreadyWaitingTunnel.status = .inactive
        }

        if let tunnelInOperation = tunnels.first(where: { $0.status != .inactive }) {
            wg_log(.info, message: "Tunnel '\(tunnel.name)' waiting for deactivation of '\(tunnelInOperation.name)'")
            tunnel.status = .waiting
            if tunnelInOperation.status != .deactivating {
                startDeactivation(of: tunnelInOperation)
            }
            return
        }

        tunnel.startActivation(activationDelegate: self.activationDelegate)
    }

    func startDeactivation(of tunnel: TunnelContainer) {
        tunnel.isAttemptingActivation = false
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

            wg_log(.debug, message: "Tunnel '\(tunnel.name)' connection status changed to '\(tunnel.tunnelProvider.connection.status)'")

            // Track what happened to our attempt to start the tunnel
            if tunnel.isAttemptingActivation {
                if session.status == .connected {
                    tunnel.isAttemptingActivation = false
                    self.activationDelegate?.tunnelActivationSucceeded(tunnel: tunnel)
                } else if session.status == .disconnected {
                    tunnel.isAttemptingActivation = false
                    self.activationDelegate?.tunnelActivationFailed(tunnel: tunnel, error: .activationFailed)
                }
            }

            // In case we're restarting the tunnel
            if (tunnel.status == .restarting) && (session.status == .disconnected || session.status == .disconnecting) {
                // Don't change tunnel.status when disconnecting for a restart
                if session.status == .disconnected {
                    tunnel.startActivation(activationDelegate: self.activationDelegate)
                }
                return
            }

            tunnel.refreshStatus()

            // In case some other tunnel is waiting for this tunnel to get deactivated
            if session.status == .disconnected || session.status == .invalid {
                if let waitingTunnel = self.tunnels.first(where: { $0.status == .waiting }) {
                    waitingTunnel.startActivation(activationDelegate: self.activationDelegate)
                }
            }
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

    fileprivate func startActivation(activationDelegate: TunnelsManagerActivationDelegate?) {
        assert(status == .inactive || status == .restarting || status == .waiting)

        guard let tunnelConfiguration = tunnelConfiguration() else { fatalError() }

        startActivation(tunnelConfiguration: tunnelConfiguration, activationDelegate: activationDelegate)
    }

    fileprivate func startActivation(recursionCount: UInt = 0,
                                     lastError: Error? = nil,
                                     tunnelConfiguration: TunnelConfiguration,
                                     activationDelegate: TunnelsManagerActivationDelegate?) {
        if recursionCount >= 8 {
            wg_log(.error, message: "startActivation: Failed after 8 attempts. Giving up with \(lastError!)")
            activationDelegate?.tunnelActivationAttemptFailed(tunnel: self, error: .failedBecauseOfTooManyErrors)
            return
        }

        wg_log(.debug, message: "startActivation: Entering (tunnel: \(self.name))")

        self.status = .activating // Ensure that no other tunnel can attempt activation until this tunnel is done trying

        guard tunnelProvider.isEnabled else {
            // In case the tunnel had gotten disabled, re-enable and save it,
            // then call this function again.
            wg_log(.debug, staticMessage: "startActivation: Tunnel is disabled. Re-enabling and saving")
            tunnelProvider.isEnabled = true
            tunnelProvider.saveToPreferences { [weak self] error in
                guard let self = self else { return }
                if error != nil {
                    wg_log(.error, message: "Error saving tunnel after re-enabling: \(error!)")
                    activationDelegate?.tunnelActivationAttemptFailed(tunnel: self, error: .failedWhileSaving)
                    return
                }
                wg_log(.debug, staticMessage: "startActivation: Tunnel saved after re-enabling")
                wg_log(.debug, staticMessage: "startActivation: Invoking startActivation")
                self.startActivation(recursionCount: recursionCount + 1, lastError: NEVPNError(NEVPNError.configurationUnknown),
                                      tunnelConfiguration: tunnelConfiguration, activationDelegate: activationDelegate)
            }
            return
        }

        // Start the tunnel
        do {
            wg_log(.debug, staticMessage: "startActivation: Starting tunnel")
            self.isAttemptingActivation = true
            try (tunnelProvider.connection as? NETunnelProviderSession)?.startTunnel()
            wg_log(.debug, staticMessage: "startActivation: Success")
            activationDelegate?.tunnelActivationAttemptSucceeded(tunnel: self)
        } catch let error {
            self.isAttemptingActivation = false
            guard let systemError = error as? NEVPNError else {
                wg_log(.error, message: "Failed to activate tunnel: Error: \(error)")
                status = .inactive
                activationDelegate?.tunnelActivationAttemptFailed(tunnel: self, error: .failedWhileStarting)
                return
            }
            guard systemError.code == NEVPNError.configurationInvalid || systemError.code == NEVPNError.configurationStale else {
                wg_log(.error, message: "Failed to activate tunnel: VPN Error: \(error)")
                status = .inactive
                activationDelegate?.tunnelActivationAttemptFailed(tunnel: self, error: .failedWhileStarting)
                return
            }
            wg_log(.debug, staticMessage: "startActivation: Will reload tunnel and then try to start it.")
            tunnelProvider.loadFromPreferences { [weak self] error in
                guard let self = self else { return }
                if error != nil {
                    wg_log(.error, message: "startActivation: Error reloading tunnel: \(error!)")
                    self.status = .inactive
                    activationDelegate?.tunnelActivationAttemptFailed(tunnel: self, error: .failedWhileLoading)
                    return
                }
                wg_log(.debug, staticMessage: "startActivation: Tunnel reloaded")
                wg_log(.debug, staticMessage: "startActivation: Invoking startActivation")
                self.startActivation(recursionCount: recursionCount + 1, lastError: systemError, tunnelConfiguration: tunnelConfiguration, activationDelegate: activationDelegate)
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
    case waiting    // Waiting for another tunnel to be brought down

    init(from systemStatus: NEVPNStatus) {
        switch systemStatus {
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
        case .waiting: return "waiting"
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
