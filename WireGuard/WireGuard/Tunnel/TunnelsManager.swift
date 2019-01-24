// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation
import NetworkExtension
import os.log

protocol TunnelsManagerListDelegate: class {
    func tunnelAdded(at index: Int)
    func tunnelModified(at index: Int)
    func tunnelMoved(from oldIndex: Int, to newIndex: Int)
    func tunnelRemoved(at index: Int, tunnel: TunnelContainer)
}

protocol TunnelsManagerActivationDelegate: class {
    func tunnelActivationAttemptFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationAttemptError) // startTunnel wasn't called or failed
    func tunnelActivationAttemptSucceeded(tunnel: TunnelContainer) // startTunnel succeeded
    func tunnelActivationFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationError) // status didn't change to connected
    func tunnelActivationSucceeded(tunnel: TunnelContainer) // status changed to connected
}

class TunnelsManager {
    private var tunnels: [TunnelContainer]
    weak var tunnelsListDelegate: TunnelsManagerListDelegate?
    weak var activationDelegate: TunnelsManagerActivationDelegate?
    private var statusObservationToken: AnyObject?
    private var waiteeObservationToken: AnyObject?
    private var configurationsObservationToken: AnyObject?

    init(tunnelProviders: [NETunnelProviderManager]) {
        tunnels = tunnelProviders.map { TunnelContainer(tunnel: $0) }.sorted { $0.name < $1.name }
        startObservingTunnelStatuses()
        startObservingTunnelConfigurations()
    }

    static func create(completionHandler: @escaping (WireGuardResult<TunnelsManager>) -> Void) {
        #if targetEnvironment(simulator)
        completionHandler(.success(TunnelsManager(tunnelProviders: MockTunnels.createMockTunnels())))
        #else
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                wg_log(.error, message: "Failed to load tunnel provider managers: \(error)")
                completionHandler(.failure(TunnelsManagerError.systemErrorOnListingTunnels(systemError: error)))
                return
            }

            let tunnelManagers = managers ?? []
            tunnelManagers.forEach { tunnelManager in
                if (tunnelManager.protocolConfiguration as? NETunnelProviderProtocol)?.migrateConfigurationIfNeeded() == true {
                    tunnelManager.saveToPreferences { _ in }
                }
            }
            completionHandler(.success(TunnelsManager(tunnelProviders: tunnelManagers)))
        }
        #endif
    }

    func reload() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            guard let self = self else { return }

            let loadedTunnelProviders = managers ?? []

            for (index, currentTunnel) in self.tunnels.enumerated().reversed() {
                if !loadedTunnelProviders.contains(where: { $0.tunnelConfiguration == currentTunnel.tunnelConfiguration }) {
                    // Tunnel was deleted outside the app
                    self.tunnels.remove(at: index)
                    self.tunnelsListDelegate?.tunnelRemoved(at: index, tunnel: currentTunnel)
                }
            }
            for loadedTunnelProvider in loadedTunnelProviders {
                if let matchingTunnel = self.tunnels.first(where: { $0.tunnelConfiguration == loadedTunnelProvider.tunnelConfiguration }) {
                    matchingTunnel.tunnelProvider = loadedTunnelProvider
                    matchingTunnel.refreshStatus()
                } else {
                    // Tunnel was added outside the app
                    let tunnel = TunnelContainer(tunnel: loadedTunnelProvider)
                    self.tunnels.append(tunnel)
                    self.tunnels.sort { $0.name < $1.name }
                    self.tunnelsListDelegate?.tunnelAdded(at: self.tunnels.firstIndex(of: tunnel)!)
                }
            }
        }
    }

    func add(tunnelConfiguration: TunnelConfiguration, activateOnDemandSetting: ActivateOnDemandSetting = ActivateOnDemandSetting.defaultSetting, completionHandler: @escaping (WireGuardResult<TunnelContainer>) -> Void) {
        let tunnelName = tunnelConfiguration.name ?? ""
        if tunnelName.isEmpty {
            completionHandler(.failure(TunnelsManagerError.tunnelNameEmpty))
            return
        }

        if tunnels.contains(where: { $0.name == tunnelName }) {
            completionHandler(.failure(TunnelsManagerError.tunnelAlreadyExistsWithThatName))
            return
        }

        let tunnelProviderManager = NETunnelProviderManager()
        tunnelProviderManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration)
        tunnelProviderManager.localizedDescription = tunnelConfiguration.name
        tunnelProviderManager.isEnabled = true

        activateOnDemandSetting.apply(on: tunnelProviderManager)

        tunnelProviderManager.saveToPreferences { [weak self] error in
            guard error == nil else {
                wg_log(.error, message: "Add: Saving configuration failed: \(error!)")
                completionHandler(.failure(TunnelsManagerError.systemErrorOnAddTunnel(systemError: error!)))
                return
            }

            guard let self = self else { return }

            let tunnel = TunnelContainer(tunnel: tunnelProviderManager)
            self.tunnels.append(tunnel)
            self.tunnels.sort { $0.name < $1.name }
            self.tunnelsListDelegate?.tunnelAdded(at: self.tunnels.firstIndex(of: tunnel)!)
            completionHandler(.success(tunnel))
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
        add(tunnelConfiguration: head) { [weak self, tail] result in
            DispatchQueue.main.async {
                self?.addMultiple(tunnelConfigurations: tail, numberSuccessful: numberSuccessful + (result.isSuccess ? 1 : 0), completionHandler: completionHandler)
            }
        }
    }

    func modify(tunnel: TunnelContainer, tunnelConfiguration: TunnelConfiguration, activateOnDemandSetting: ActivateOnDemandSetting, completionHandler: @escaping (TunnelsManagerError?) -> Void) {
        let tunnelName = tunnelConfiguration.name ?? ""
        if tunnelName.isEmpty {
            completionHandler(TunnelsManagerError.tunnelNameEmpty)
            return
        }

        let tunnelProviderManager = tunnel.tunnelProvider
        let isNameChanged = tunnelName != tunnelProviderManager.localizedDescription
        if isNameChanged {
            guard !tunnels.contains(where: { $0.name == tunnelName }) else {
                completionHandler(TunnelsManagerError.tunnelAlreadyExistsWithThatName)
                return
            }
            tunnel.name = tunnelName
        }

        tunnelProviderManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration)
        tunnelProviderManager.localizedDescription = tunnelConfiguration.name
        tunnelProviderManager.isEnabled = true

        let isActivatingOnDemand = !tunnelProviderManager.isOnDemandEnabled && activateOnDemandSetting.isActivateOnDemandEnabled
        activateOnDemandSetting.apply(on: tunnelProviderManager)

        tunnelProviderManager.saveToPreferences { [weak self] error in
            guard error == nil else {
                wg_log(.error, message: "Modify: Saving configuration failed: \(error!)")
                completionHandler(TunnelsManagerError.systemErrorOnModifyTunnel(systemError: error!))
                return
            }
            guard let self = self else { return }

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
                        completionHandler(TunnelsManagerError.systemErrorOnModifyTunnel(systemError: error!))
                        return
                    }
                    completionHandler(nil)
                }
            } else {
                completionHandler(nil)
            }
        }
    }

    func remove(tunnel: TunnelContainer, completionHandler: @escaping (TunnelsManagerError?) -> Void) {
        let tunnelProviderManager = tunnel.tunnelProvider

        tunnelProviderManager.removeFromPreferences { [weak self] error in
            guard error == nil else {
                wg_log(.error, message: "Remove: Saving configuration failed: \(error!)")
                completionHandler(TunnelsManagerError.systemErrorOnRemoveTunnel(systemError: error!))
                return
            }
            if let self = self {
                let index = self.tunnels.firstIndex(of: tunnel)!
                self.tunnels.remove(at: index)
                self.tunnelsListDelegate?.tunnelRemoved(at: index, tunnel: tunnel)
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
        return tunnels.first { $0.name == tunnelName }
    }

    func waitingTunnel() -> TunnelContainer? {
        return tunnels.first { $0.status == .waiting }
    }

    func tunnelInOperation() -> TunnelContainer? {
        if let waitingTunnelObject = waitingTunnel() {
            return waitingTunnelObject
        }
        return tunnels.first { $0.status != .inactive }
    }

    func startActivation(of tunnel: TunnelContainer) {
        guard tunnels.contains(tunnel) else { return } // Ensure it's not deleted
        guard tunnel.status == .inactive else {
            activationDelegate?.tunnelActivationAttemptFailed(tunnel: tunnel, error: .tunnelIsNotInactive)
            return
        }

        if let alreadyWaitingTunnel = tunnels.first(where: { $0.status == .waiting }) {
            alreadyWaitingTunnel.status = .inactive
        }

        if let tunnelInOperation = tunnels.first(where: { $0.status != .inactive }) {
            wg_log(.info, message: "Tunnel '\(tunnel.name)' waiting for deactivation of '\(tunnelInOperation.name)'")
            tunnel.status = .waiting
            activateWaitingTunnelOnDeactivation(of: tunnelInOperation)
            if tunnelInOperation.status != .deactivating {
                startDeactivation(of: tunnelInOperation)
            }
            return
        }

        #if targetEnvironment(simulator)
        tunnel.status = .active
        #else
        tunnel.startActivation(activationDelegate: activationDelegate)
        #endif
    }

    func startDeactivation(of tunnel: TunnelContainer) {
        tunnel.isAttemptingActivation = false
        guard tunnel.status != .inactive && tunnel.status != .deactivating else { return }
        #if targetEnvironment(simulator)
        tunnel.status = .inactive
        #else
        tunnel.startDeactivation()
        #endif
    }

    func refreshStatuses() {
        tunnels.forEach { $0.refreshStatus() }
    }

    private func activateWaitingTunnelOnDeactivation(of tunnel: TunnelContainer) {
        waiteeObservationToken = tunnel.observe(\.status) { [weak self] tunnel, _ in
            guard let self = self else { return }
            if tunnel.status == .inactive {
                if let waitingTunnel = self.tunnels.first(where: { $0.status == .waiting }) {
                    waitingTunnel.startActivation(activationDelegate: self.activationDelegate)
                }
                self.waiteeObservationToken = nil
            }
        }
    }

    private func startObservingTunnelStatuses() {
        statusObservationToken = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: OperationQueue.main) { [weak self] statusChangeNotification in
            guard let self = self,
                let session = statusChangeNotification.object as? NETunnelProviderSession,
                let tunnelProvider = session.manager as? NETunnelProviderManager,
                let tunnelConfiguration = tunnelProvider.tunnelConfiguration,
                let tunnel = self.tunnels.first(where: { $0.tunnelConfiguration == tunnelConfiguration }) else { return }
            if tunnel.tunnelProvider != tunnelProvider {
                tunnel.tunnelProvider = tunnelProvider
                tunnel.refreshStatus()
            }

            wg_log(.debug, message: "Tunnel '\(tunnel.name)' connection status changed to '\(tunnel.tunnelProvider.connection.status)'")

            if tunnel.isAttemptingActivation {
                if session.status == .connected {
                    tunnel.isAttemptingActivation = false
                    self.activationDelegate?.tunnelActivationSucceeded(tunnel: tunnel)
                } else if session.status == .disconnected {
                    tunnel.isAttemptingActivation = false
                    if let (title, message) = lastErrorTextFromNetworkExtension(for: tunnel) {
                        self.activationDelegate?.tunnelActivationFailed(tunnel: tunnel, error: .activationFailedWithExtensionError(title: title, message: message, wasOnDemandEnabled: tunnelProvider.isOnDemandEnabled))
                    } else {
                        self.activationDelegate?.tunnelActivationFailed(tunnel: tunnel, error: .activationFailed(wasOnDemandEnabled: tunnelProvider.isOnDemandEnabled))
                    }
                }
            }

            if (tunnel.status == .restarting) && (session.status == .disconnected || session.status == .disconnecting) {
                if session.status == .disconnected {
                    tunnel.startActivation(activationDelegate: self.activationDelegate)
                }
                return
            }

            tunnel.refreshStatus()
        }
    }

    func startObservingTunnelConfigurations() {
        configurationsObservationToken = NotificationCenter.default.addObserver(forName: .NEVPNConfigurationChange, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.reload()
        }
    }

}

private func lastErrorTextFromNetworkExtension(for tunnel: TunnelContainer) -> (title: String, message: String)? {
    guard let lastErrorFileURL = FileManager.networkExtensionLastErrorFileURL else { return nil }
    guard let lastErrorData = try? Data(contentsOf: lastErrorFileURL) else { return nil }
    guard let lastErrorStrings = String(data: lastErrorData, encoding: .utf8)?.splitToArray(separator: "\n") else { return nil }
    guard lastErrorStrings.count == 2 && tunnel.activationAttemptId == lastErrorStrings[0] else { return nil }

    if let extensionError = PacketTunnelProviderError(rawValue: lastErrorStrings[1]) {
        return extensionError.alertText
    }

    return (tr("alertTunnelActivationFailureTitle"), tr("alertTunnelActivationFailureMessage"))
}

class TunnelContainer: NSObject {
    @objc dynamic var name: String
    @objc dynamic var status: TunnelStatus

    @objc dynamic var isActivateOnDemandEnabled: Bool

    var isAttemptingActivation = false {
        didSet {
            if isAttemptingActivation {
                self.activationTimer?.invalidate()
                let activationTimer = Timer(timeInterval: 5 /* seconds */, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    wg_log(.debug, message: "Status update notification timeout for tunnel '\(self.name)'. Tunnel status is now '\(self.tunnelProvider.connection.status)'.")
                    switch self.tunnelProvider.connection.status {
                    case .connected, .disconnected, .invalid:
                        self.activationTimer?.invalidate()
                        self.activationTimer = nil
                    default:
                        break
                    }
                    self.refreshStatus()
                }
                self.activationTimer = activationTimer
                RunLoop.main.add(activationTimer, forMode: .default)
            }
        }
    }
    var activationAttemptId: String?
    var activationTimer: Timer?

    fileprivate var tunnelProvider: NETunnelProviderManager

    var tunnelConfiguration: TunnelConfiguration? {
        return tunnelProvider.tunnelConfiguration
    }

    var activateOnDemandSetting: ActivateOnDemandSetting {
        return ActivateOnDemandSetting(from: tunnelProvider)
    }

    init(tunnel: NETunnelProviderManager) {
        name = tunnel.localizedDescription ?? "Unnamed"
        let status = TunnelStatus(from: tunnel.connection.status)
        self.status = status
        isActivateOnDemandEnabled = tunnel.isOnDemandEnabled
        tunnelProvider = tunnel
        super.init()
    }

    func getRuntimeTunnelConfiguration(completionHandler: @escaping ((TunnelConfiguration?) -> Void)) {
        guard status != .inactive, let session = tunnelProvider.connection as? NETunnelProviderSession else {
            completionHandler(tunnelConfiguration)
            return
        }
        guard nil != (try? session.sendProviderMessage(Data(bytes: [ 0 ]), responseHandler: {
            guard self.status != .inactive, let data = $0, let base = self.tunnelConfiguration, let settings = String(data: data, encoding: .utf8) else {
                completionHandler(self.tunnelConfiguration)
                return
            }
            completionHandler((try? TunnelConfiguration(fromUapiConfig: settings, basedOn: base)) ?? self.tunnelConfiguration)
        })) else {
            completionHandler(tunnelConfiguration)
            return
        }
    }

    func refreshStatus() {
        let status = TunnelStatus(from: tunnelProvider.connection.status)
        self.status = status
        isActivateOnDemandEnabled = tunnelProvider.isOnDemandEnabled
    }

    //swiftlint:disable:next function_body_length
    fileprivate func startActivation(recursionCount: UInt = 0, lastError: Error? = nil, activationDelegate: TunnelsManagerActivationDelegate?) {
        if recursionCount >= 8 {
            wg_log(.error, message: "startActivation: Failed after 8 attempts. Giving up with \(lastError!)")
            activationDelegate?.tunnelActivationAttemptFailed(tunnel: self, error: .failedBecauseOfTooManyErrors(lastSystemError: lastError!))
            return
        }

        wg_log(.debug, message: "startActivation: Entering (tunnel: \(name))")

        status = .activating // Ensure that no other tunnel can attempt activation until this tunnel is done trying

        guard tunnelProvider.isEnabled else {
            // In case the tunnel had gotten disabled, re-enable and save it,
            // then call this function again.
            wg_log(.debug, staticMessage: "startActivation: Tunnel is disabled. Re-enabling and saving")
            tunnelProvider.isEnabled = true
            tunnelProvider.saveToPreferences { [weak self] error in
                guard let self = self else { return }
                if error != nil {
                    wg_log(.error, message: "Error saving tunnel after re-enabling: \(error!)")
                    activationDelegate?.tunnelActivationAttemptFailed(tunnel: self, error: .failedWhileSaving(systemError: error!))
                    return
                }
                wg_log(.debug, staticMessage: "startActivation: Tunnel saved after re-enabling, invoking startActivation")
                self.startActivation(recursionCount: recursionCount + 1, lastError: NEVPNError(NEVPNError.configurationUnknown), activationDelegate: activationDelegate)
            }
            return
        }

        // Start the tunnel
        do {
            wg_log(.debug, staticMessage: "startActivation: Starting tunnel")
            isAttemptingActivation = true
            let activationAttemptId = UUID().uuidString
            self.activationAttemptId = activationAttemptId
            try (tunnelProvider.connection as? NETunnelProviderSession)?.startTunnel(options: ["activationAttemptId": activationAttemptId])
            wg_log(.debug, staticMessage: "startActivation: Success")
            activationDelegate?.tunnelActivationAttemptSucceeded(tunnel: self)
        } catch let error {
            isAttemptingActivation = false
            guard let systemError = error as? NEVPNError else {
                wg_log(.error, message: "Failed to activate tunnel: Error: \(error)")
                status = .inactive
                activationDelegate?.tunnelActivationAttemptFailed(tunnel: self, error: .failedWhileStarting(systemError: error))
                return
            }
            guard systemError.code == NEVPNError.configurationInvalid || systemError.code == NEVPNError.configurationStale else {
                wg_log(.error, message: "Failed to activate tunnel: VPN Error: \(error)")
                status = .inactive
                activationDelegate?.tunnelActivationAttemptFailed(tunnel: self, error: .failedWhileStarting(systemError: systemError))
                return
            }
            wg_log(.debug, staticMessage: "startActivation: Will reload tunnel and then try to start it.")
            tunnelProvider.loadFromPreferences { [weak self] error in
                guard let self = self else { return }
                if error != nil {
                    wg_log(.error, message: "startActivation: Error reloading tunnel: \(error!)")
                    self.status = .inactive
                    activationDelegate?.tunnelActivationAttemptFailed(tunnel: self, error: .failedWhileLoading(systemError: systemError))
                    return
                }
                wg_log(.debug, staticMessage: "startActivation: Tunnel reloaded, invoking startActivation")
                self.startActivation(recursionCount: recursionCount + 1, lastError: systemError, activationDelegate: activationDelegate)
            }
        }
    }

    fileprivate func startDeactivation() {
        (tunnelProvider.connection as? NETunnelProviderSession)?.stopTunnel()
    }
}

extension NETunnelProviderManager {
    var tunnelConfiguration: TunnelConfiguration? {
        return (protocolConfiguration as? NETunnelProviderProtocol)?.asTunnelConfiguration(called: localizedDescription)
    }
}
