// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Intents

class IntentHandling: NSObject {

    public enum IntentError: Error {
        case failedDecode
        case wrongTunnel
        case unknown
    }

    var tunnelsManager: TunnelsManager?

    var onTunnelsManagerReady: ((TunnelsManager) -> Void)?

    var onTunnelStatusActivationReturn: ((Bool) -> Void)?

    override init() {
        super.init()

        TunnelsManager.create { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                wg_log(.error, message: error.localizedDescription)
            case .success(let tunnelsManager):
                self.tunnelsManager = tunnelsManager

                self.tunnelsManager?.activationDelegate = self

                self.onTunnelsManagerReady?(tunnelsManager)
                self.onTunnelsManagerReady = nil
            }
        }
    }

    init(tunnelsManager: TunnelsManager) {
        super.init()

        self.tunnelsManager = tunnelsManager
    }
}

extension IntentHandling {

    private func allTunnelNames(completion: @escaping ([String]?) -> Void) {
        let getTunnelsNameBlock: (TunnelsManager) -> Void = { tunnelsManager in
            let tunnelsNames = tunnelsManager.mapTunnels { $0.name }
            return completion(tunnelsNames)
        }

        if let tunnelsManager = tunnelsManager {
            getTunnelsNameBlock(tunnelsManager)
        } else {
            if onTunnelsManagerReady != nil {
                wg_log(.error, message: "Overriding onTunnelsManagerReady action in allTunnelNames function. This should not happen.")
            }
            onTunnelsManagerReady = getTunnelsNameBlock
        }
    }

    private func allTunnelPeers(for tunnelName: String, completion: @escaping (Result<[String], IntentError>) -> Void) {
        let getPeersFromConfigBlock: (TunnelsManager) -> Void = { tunnelsManager in
            guard let tunnel = tunnelsManager.tunnel(named: tunnelName) else {
                return completion(.failure(.wrongTunnel))
            }

            guard let publicKeys = tunnel.tunnelConfiguration?.peers.map({ $0.publicKey.base64Key }) else {
                return completion(.failure(.unknown))
            }
            return completion(.success(publicKeys))
        }

        if let tunnelsManager = tunnelsManager {
            getPeersFromConfigBlock(tunnelsManager)
        } else {
            if onTunnelsManagerReady != nil {
                wg_log(.error, message: "Overriding onTunnelsManagerReady action in allTunnelPeers function. This should not happen.")
            }
            onTunnelsManagerReady = getPeersFromConfigBlock
        }
    }
}

extension IntentHandling: GetPeersIntentHandling {

    @available(iOSApplicationExtension 14.0, *)
    func provideTunnelOptionsCollection(for intent: GetPeersIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {

        self.allTunnelNames { tunnelsNames in
            let tunnelsNamesObjects = (tunnelsNames ?? []).map { NSString(string: $0) }

            let objectCollection = INObjectCollection(items: tunnelsNamesObjects)
            completion(objectCollection, nil)
        }
    }

    func handle(intent: GetPeersIntent, completion: @escaping (GetPeersIntentResponse) -> Void) {
        guard let tunnel = intent.tunnel else {
            return completion(GetPeersIntentResponse(code: .failure, userActivity: nil))
        }

        self.allTunnelPeers(for: tunnel) { peersResult in
            switch peersResult {
            case .success(let peers):
                let response = GetPeersIntentResponse(code: .success, userActivity: nil)
                response.peersPublicKeys = peers
                completion(response)

            case .failure(let error):
                switch error {
                case .wrongTunnel:
                    completion(GetPeersIntentResponse(code: .wrongTunnel, userActivity: nil))
                default:
                    completion(GetPeersIntentResponse(code: .failure, userActivity: nil))
                }
            }
        }
    }

}

extension IntentHandling: UpdateConfigurationIntentHandling {

    @available(iOSApplicationExtension 14.0, *)
    func provideTunnelOptionsCollection(for intent: UpdateConfigurationIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
        self.allTunnelNames { tunnelsNames in
            let tunnelsNamesObjects = (tunnelsNames ?? []).map { NSString(string: $0) }

            let objectCollection = INObjectCollection(items: tunnelsNamesObjects)
            completion(objectCollection, nil)
        }
    }

    func handle(intent: UpdateConfigurationIntent, completion: @escaping (UpdateConfigurationIntentResponse) -> Void) {
        // Due to an Apple bug (https://developer.apple.com/forums/thread/96020) we can't update VPN
        // configuration from extensions at the moment, so we should handle the action in the app.
        // We check that the configuration update data is valid and then launch the main app.

        guard let tunnelName = intent.tunnel,
              let configurationString = intent.configuration else {
                  wg_log(.error, message: "Failed to get informations to update the configuration")
                  completion(UpdateConfigurationIntentResponse(code: .failure, userActivity: nil))
                  return
        }

        var configurations: [String: [String: String]]

        let configurationsData = Data(configurationString.utf8)
        do {
            // Make sure this JSON is in the format we expect
            if let decodedJson = try JSONSerialization.jsonObject(with: configurationsData, options: []) as? [String: [String: String]] {
                configurations = decodedJson
            } else {
                throw IntentError.failedDecode
            }
        } catch _ {
            wg_log(.error, message: "Failed to decode configuration data in JSON format for \(tunnelName)")
            completion(UpdateConfigurationIntentResponse(code: .wrongConfiguration, userActivity: nil))
            return
        }

        var activity: NSUserActivity?
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            activity = NSUserActivity(activityType: "\(bundleIdentifier).activity.update-tunnel-config")
            activity?.userInfo = ["TunnelName": tunnelName,
                                  "Configuration": configurations]
        }

        completion(UpdateConfigurationIntentResponse(code: .continueInApp, userActivity: activity))
    }

}

extension IntentHandling: SetTunnelStatusIntentHandling {

    @available(iOSApplicationExtension 14.0, *)
    func provideTunnelOptionsCollection(for intent: SetTunnelStatusIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {

        self.allTunnelNames { tunnelsNames in
            let tunnelsNamesObjects = (tunnelsNames ?? []).map { NSString(string: $0) }

            let objectCollection = INObjectCollection(items: tunnelsNamesObjects)
            completion(objectCollection, nil)
        }
    }

    func handle(intent: SetTunnelStatusIntent, completion: @escaping (SetTunnelStatusIntentResponse) -> Void) {
        guard let tunnelName = intent.tunnel else {
            return completion(SetTunnelStatusIntentResponse(code: .failure, userActivity: nil))
        }

        let setTunnelStatusResultBlock: (Bool) -> Void = { result in
            if result {
                completion(SetTunnelStatusIntentResponse(code: .success, userActivity: nil))
            } else {
                completion(SetTunnelStatusIntentResponse(code: .failure, userActivity: nil))
            }
        }

        let updateStatusBlock: (TunnelsManager) -> Void = { tunnelsManager in
            guard let tunnel = tunnelsManager.tunnel(named: tunnelName) else {
                completion(SetTunnelStatusIntentResponse(code: .failure, userActivity: nil))
                return
            }

            let operation = intent.operation
            let isOn: Bool

            if operation == .toggle {
                switch tunnel.status {
                case .inactive:
                    isOn = true
                case .active:
                    isOn = false
                default:
                    wg_log(.error, message: "SetTunnelStatusIntent action cannot be executed due to the current state of \(tunnelName) tunnel: \(tunnel.status)")
                    completion(SetTunnelStatusIntentResponse(code: .failure, userActivity: nil))
                    return
                }

            } else if operation == .turn {
                if (tunnel.status == .inactive) || (tunnel.status == .active) {
                    isOn = (intent.state == .on)

                    if (isOn && tunnel.status == .active) || (!isOn && tunnel.status == .inactive) {
                        wg_log(.debug, message: "Tunnel \(tunnelName) is already \(isOn ? "active" : "inactive")")
                        completion(SetTunnelStatusIntentResponse(code: .success, userActivity: nil))
                        return
                    }
                } else {
                    wg_log(.error, message: "SetTunnelStatusIntent action cannot be executed due to the current state of \(tunnelName) tunnel: \(tunnel.status)")
                    completion(SetTunnelStatusIntentResponse(code: .failure, userActivity: nil))
                    return
                }

            } else {
                wg_log(.error, message: "Invalid 'operation' option in action")
                completion(SetTunnelStatusIntentResponse(code: .failure, userActivity: nil))
                return
            }

            if tunnel.hasOnDemandRules {
                tunnelsManager.setOnDemandEnabled(isOn, on: tunnel) { error in
                    guard error == nil else {
                        wg_log(.error, message: "Error setting OnDemand status: \(error!.localizedDescription).")
                        completion(SetTunnelStatusIntentResponse(code: .failure, userActivity: nil))
                        return
                    }

                    if !isOn {
                        tunnelsManager.startDeactivation(of: tunnel)
                    }

                    completion(SetTunnelStatusIntentResponse(code: .success, userActivity: nil))
                }
            } else {
                if isOn {
                    self.onTunnelStatusActivationReturn = setTunnelStatusResultBlock
                    tunnelsManager.startActivation(of: tunnel)
                } else {
                    tunnelsManager.startDeactivation(of: tunnel)
                    completion(SetTunnelStatusIntentResponse(code: .success, userActivity: nil))
                }
            }
        }

        if let tunnelsManager = tunnelsManager {
            updateStatusBlock(tunnelsManager)
        } else {
            if onTunnelsManagerReady != nil {
                wg_log(.error, message: "Overriding onTunnelsManagerReady action in allTunnelPeers function. This should not happen.")
            }
            onTunnelsManagerReady = updateStatusBlock
        }
    }

}

extension IntentHandling: TunnelsManagerActivationDelegate {
    func tunnelActivationAttemptFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationAttemptError) {
        wg_log(.error, message: "Tunnel Activation Attempt Failed with error: \(error.localizedDescription)")
        self.onTunnelStatusActivationReturn?(false)
    }

    func tunnelActivationAttemptSucceeded(tunnel: TunnelContainer) {
        // Nothing to do, we wait tunnelActivationSucceeded to be sure all activation logic has been executed
    }

    func tunnelActivationFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationError) {
        wg_log(.error, message: "Tunnel Activation Failed with error: \(error.localizedDescription)")
        self.onTunnelStatusActivationReturn?(false)
    }

    func tunnelActivationSucceeded(tunnel: TunnelContainer) {
        self.onTunnelStatusActivationReturn?(true)
    }

}
