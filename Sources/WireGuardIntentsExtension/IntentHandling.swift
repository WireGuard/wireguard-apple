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
