// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import NetworkExtension
import os.log

protocol TunnelsManagerListDelegate: class {
    func tunnelAdded(at: Int)
    func tunnelModified(at: Int)
    func tunnelMoved(at oldIndex: Int, to newIndex: Int)
    func tunnelRemoved(at: Int)
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
    case tunnelActivationAttemptFailed // startTunnel() throwed
    case tunnelActivationFailedInternalError // startTunnel() succeeded, but activation failed
    case tunnelActivationFailedNoInternetConnection // startTunnel() succeeded, but activation failed since no internet

    func alertText() -> (String, String) {
        switch (self) {
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

        case .tunnelActivationAttemptFailed:
            return ("Activation failure", "The tunnel could not be activated due to an internal error")
        case .tunnelActivationFailedInternalError:
            return ("Activation failure", "The tunnel could not be activated due to an internal error")
        case .tunnelActivationFailedNoInternetConnection:
            return ("Activation failure", "No internet connection")
        }
    }
}

enum TunnelsManagerResult<T> {
    case success(T)
    case failure(TunnelsManagerError)

    var value: T? {
        switch (self) {
        case .success(let v): return v
        case .failure(_): return nil
        }
    }

    var error: TunnelsManagerError? {
        switch (self) {
        case .success(_): return nil
        case .failure(let e): return e
        }
    }

    var isSuccess: Bool {
        switch (self) {
        case .success(_): return true
        case .failure(_): return false
        }
    }
}

class TunnelsManager {

    private var tunnels: [TunnelContainer]
    weak var tunnelsListDelegate: TunnelsManagerListDelegate?
    weak var activationDelegate: TunnelsManagerActivationDelegate?

    private var isAddingTunnel: Bool = false
    private var isModifyingTunnel: Bool = false
    private var isDeletingTunnel: Bool = false

    init(tunnelProviders: [NETunnelProviderManager]) {
        self.tunnels = tunnelProviders.map { TunnelContainer(tunnel: $0) }.sorted { $0.name < $1.name }
    }

    static func create(completionHandler: @escaping (TunnelsManagerResult<TunnelsManager>) -> Void) {
        #if targetEnvironment(simulator)
        // NETunnelProviderManager APIs don't work on the simulator
        completionHandler(.success(TunnelsManager(tunnelProviders: [])))
        #else
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
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
             completionHandler: @escaping (TunnelsManagerResult<TunnelContainer>) -> Void) {
        let tunnelName = tunnelConfiguration.interface.name
        if tunnelName.isEmpty {
            completionHandler(.failure(TunnelsManagerError.tunnelNameEmpty))
            return
        }

        if self.tunnels.contains(where: { $0.name == tunnelName }) {
            completionHandler(.failure(TunnelsManagerError.tunnelAlreadyExistsWithThatName))
            return
        }

        isAddingTunnel = true
        let tunnelProviderManager = NETunnelProviderManager()
        tunnelProviderManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration)
        tunnelProviderManager.localizedDescription = tunnelName
        tunnelProviderManager.isEnabled = true

        activateOnDemandSetting.apply(on: tunnelProviderManager)

        tunnelProviderManager.saveToPreferences { [weak self] (error) in
            defer { self?.isAddingTunnel = false }
            guard (error == nil) else {
                os_log("Add: Saving configuration failed: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                completionHandler(.failure(TunnelsManagerError.vpnSystemErrorOnAddTunnel))
                return
            }
            if let s = self {
                let tunnel = TunnelContainer(tunnel: tunnelProviderManager)
                s.tunnels.append(tunnel)
                s.tunnels.sort { $0.name < $1.name }
                s.tunnelsListDelegate?.tunnelAdded(at: s.tunnels.firstIndex(of: tunnel)!)
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
        self.add(tunnelConfiguration: head) { [weak self, tail] (result) in
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

        isModifyingTunnel = true

        let tunnelProviderManager = tunnel.tunnelProvider
        let isNameChanged = (tunnelName != tunnelProviderManager.localizedDescription)
        var oldName: String?
        if (isNameChanged) {
            if self.tunnels.contains(where: { $0.name == tunnelName }) {
                completionHandler(TunnelsManagerError.tunnelAlreadyExistsWithThatName)
                return
            }
            oldName = tunnel.name
            tunnel.name = tunnelName
        }
        tunnelProviderManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration)
        tunnelProviderManager.localizedDescription = tunnelName
        tunnelProviderManager.isEnabled = true

        let isActivatingOnDemand = (!tunnelProviderManager.isOnDemandEnabled && activateOnDemandSetting.isActivateOnDemandEnabled)
        activateOnDemandSetting.apply(on: tunnelProviderManager)

        tunnelProviderManager.saveToPreferences { [weak self] (error) in
            defer { self?.isModifyingTunnel = false }
            guard (error == nil) else {
                os_log("Modify: Saving configuration failed: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                completionHandler(TunnelsManagerError.vpnSystemErrorOnModifyTunnel)
                return
            }
            if let s = self {
                if (isNameChanged) {
                    let oldIndex = s.tunnels.firstIndex(of: tunnel)!
                    s.tunnels.sort { $0.name < $1.name }
                    let newIndex = s.tunnels.firstIndex(of: tunnel)!
                    s.tunnelsListDelegate?.tunnelMoved(at: oldIndex, to: newIndex)
                }
                s.tunnelsListDelegate?.tunnelModified(at: s.tunnels.firstIndex(of: tunnel)!)

                if (tunnel.status == .active || tunnel.status == .activating || tunnel.status == .reasserting) {
                    // Turn off the tunnel, and then turn it back on, so the changes are made effective
                    tunnel.beginRestart()
                }

                if (isActivatingOnDemand) {
                    // Reload tunnel after saving.
                    // Without this, the tunnel stopes getting updates on the tunnel status from iOS.
                    tunnelProviderManager.loadFromPreferences { (error) in
                        tunnel.isActivateOnDemandEnabled = tunnelProviderManager.isOnDemandEnabled
                        guard (error == nil) else {
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

        isDeletingTunnel = true

        tunnelProviderManager.removeFromPreferences { [weak self] (error) in
            defer { self?.isDeletingTunnel = false }
            guard (error == nil) else {
                os_log("Remove: Saving configuration failed: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                completionHandler(TunnelsManagerError.vpnSystemErrorOnRemoveTunnel)
                return
            }
            if let s = self {
                let index = s.tunnels.firstIndex(of: tunnel)!
                s.tunnels.remove(at: index)
                s.tunnelsListDelegate?.tunnelRemoved(at: index)
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

    func startActivation(of tunnel: TunnelContainer, completionHandler: @escaping (TunnelsManagerError?) -> Void) {
        guard (tunnel.status == .inactive) else {
            return
        }

        func _startActivation(of tunnel: TunnelContainer, completionHandler: @escaping (TunnelsManagerError?) -> Void) {
            tunnel.onActivationCommitted = { [weak self] (success) in
                if (!success) {
                    let error = (InternetReachability.currentStatus() == .notReachable ?
                        TunnelsManagerError.tunnelActivationFailedNoInternetConnection :
                        TunnelsManagerError.tunnelActivationFailedInternalError)
                    self?.activationDelegate?.tunnelActivationFailed(tunnel: tunnel, error: error)
                }
            }
            tunnel.startActivation(completionHandler: completionHandler)
        }

        if let tunnelInOperation = tunnels.first(where: { $0.status != .inactive }) {
            tunnel.status = .waiting
            tunnelInOperation.onDeactivationComplete = {
                _startActivation(of: tunnel, completionHandler: completionHandler)
            }
            startDeactivation(of: tunnelInOperation)
        } else {
            _startActivation(of: tunnel, completionHandler: completionHandler)
        }
    }

    func startDeactivation(of tunnel: TunnelContainer) {
        if (tunnel.status == .inactive) {
            return
        }
        tunnel.startDeactivation()
    }

    func refreshStatuses() {
        for t in tunnels {
            t.refreshStatus()
        }
    }
}

class TunnelContainer: NSObject {
    @objc dynamic var name: String
    @objc dynamic var status: TunnelStatus

    @objc dynamic var isActivateOnDemandEnabled: Bool {
        didSet {
            if (isActivateOnDemandEnabled) {
                startObservingTunnelStatus()
            }
        }
    }

    var isAttemptingActivation: Bool = false
    var onActivationCommitted: ((Bool) -> Void)?
    var onDeactivationComplete: (() -> Void)?

    fileprivate let tunnelProvider: NETunnelProviderManager
    private var statusObservationToken: AnyObject?

    init(tunnel: NETunnelProviderManager) {
        self.name = tunnel.localizedDescription ?? "Unnamed"
        let status = TunnelStatus(from: tunnel.connection.status)
        self.status = status
        self.isActivateOnDemandEnabled = tunnel.isOnDemandEnabled
        self.tunnelProvider = tunnel
        super.init()
        if (status != .inactive || isActivateOnDemandEnabled) {
            startObservingTunnelStatus()
        }
    }

    func tunnelConfiguration() -> TunnelConfiguration? {
        return (tunnelProvider.protocolConfiguration as! NETunnelProviderProtocol).tunnelConfiguration()
    }

    func activateOnDemandSetting() -> ActivateOnDemandSetting {
        return ActivateOnDemandSetting(from: tunnelProvider)
    }

    func refreshStatus() {
        let status = TunnelStatus(from: self.tunnelProvider.connection.status)
        self.status = status
        self.isActivateOnDemandEnabled = self.tunnelProvider.isOnDemandEnabled
        if (status != .inactive || isActivateOnDemandEnabled) {
            startObservingTunnelStatus()
        }
    }

    fileprivate func startActivation(completionHandler: @escaping (TunnelsManagerError?) -> Void) {
        assert(status == .inactive || status == .restarting || status == .waiting)

        guard let tunnelConfiguration = tunnelConfiguration() else { fatalError() }

        onDeactivationComplete = nil
        isAttemptingActivation = true
        startActivation(tunnelConfiguration: tunnelConfiguration, completionHandler: completionHandler)
    }

    fileprivate func startActivation(recursionCount: UInt = 0,
                                     lastError: Error? = nil,
                                     tunnelConfiguration: TunnelConfiguration,
                                     completionHandler: @escaping (TunnelsManagerError?) -> Void) {
        if (recursionCount >= 8) {
            os_log("startActivation: Failed after 8 attempts. Giving up with %{public}@", log: OSLog.default, type: .error, "\(lastError!)")
            completionHandler(TunnelsManagerError.tunnelActivationAttemptFailed)
            return
        }

        os_log("startActivation: Entering", log: OSLog.default, type: .debug)

        guard (tunnelProvider.isEnabled) else {
            // In case the tunnel had gotten disabled, re-enable and save it,
            // then call this function again.
            os_log("startActivation: Tunnel is disabled. Re-enabling and saving", log: OSLog.default, type: .info)
            tunnelProvider.isEnabled = true
            tunnelProvider.saveToPreferences { [weak self] (error) in
                if (error != nil) {
                    os_log("Error saving tunnel after re-enabling: %{public}@", log: OSLog.default, type: .error, "\(error!)")
                    completionHandler(TunnelsManagerError.tunnelActivationAttemptFailed)
                    return
                }
                os_log("startActivation: Tunnel saved after re-enabling", log: OSLog.default, type: .info)
                os_log("startActivation: Invoking startActivation", log: OSLog.default, type: .debug)
                self?.startActivation(recursionCount: recursionCount + 1, lastError: NEVPNError(NEVPNError.configurationUnknown), tunnelConfiguration: tunnelConfiguration, completionHandler: completionHandler)
            }
            return
        }

        // Start the tunnel
        startObservingTunnelStatus()
        let session = (tunnelProvider.connection as! NETunnelProviderSession)
        do {
            os_log("startActivation: Starting tunnel", log: OSLog.default, type: .debug)
            try session.startTunnel()
            os_log("startActivation: Success", log: OSLog.default, type: .debug)
            completionHandler(nil)
        } catch (let error) {
            guard let vpnError = error as? NEVPNError else {
                os_log("Failed to activate tunnel: Error: %{public}@", log: OSLog.default, type: .debug, "\(error)")
                status = .inactive
                completionHandler(TunnelsManagerError.tunnelActivationAttemptFailed)
                return
            }
            guard (vpnError.code == NEVPNError.configurationInvalid || vpnError.code == NEVPNError.configurationStale) else {
                os_log("Failed to activate tunnel: VPN Error: %{public}@", log: OSLog.default, type: .debug, "\(error)")
                status = .inactive
                completionHandler(TunnelsManagerError.tunnelActivationAttemptFailed)
                return
            }
            assert(vpnError.code == NEVPNError.configurationInvalid || vpnError.code == NEVPNError.configurationStale)
            os_log("startActivation: Will reload tunnel and then try to start it. ", log: OSLog.default, type: .info)
            tunnelProvider.loadFromPreferences { [weak self] (error) in
                if (error != nil) {
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
                if (s.isAttemptingActivation) {
                    if (connection.status == .connecting || connection.status == .connected) {
                        // We tried to start the tunnel, and that attempt is on track to become succeessful
                        s.onActivationCommitted?(true)
                        s.onActivationCommitted = nil
                    } else if (connection.status == .disconnecting || connection.status == .disconnected) {
                        // We tried to start the tunnel, but that attempt didn't succeed
                        s.onActivationCommitted?(false)
                        s.onActivationCommitted = nil
                    }
                    s.isAttemptingActivation = false
                }
                if ((s.status == .restarting) && (connection.status == .disconnected || connection.status == .disconnecting)) {
                    // Don't change s.status when disconnecting for a restart
                    if (connection.status == .disconnected) {
                        self?.startActivation(completionHandler: { _ in })
                    }
                    return
                }
                s.status = TunnelStatus(from: connection.status)
                if (s.status == .inactive) {
                    s.onDeactivationComplete?()
                    s.onDeactivationComplete = nil
                    if (!s.isActivateOnDemandEnabled) {
                        s.statusObservationToken = nil
                    }
                }
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
    case waiting    // Waiting for another tunnel to be brought down

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
