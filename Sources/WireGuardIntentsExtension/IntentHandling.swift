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

    override init() {
        super.init()

        TunnelsManager.create { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                wg_log(.error, message: error.localizedDescription)
            case .success(let tunnelsManager):
                self.tunnelsManager = tunnelsManager

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
