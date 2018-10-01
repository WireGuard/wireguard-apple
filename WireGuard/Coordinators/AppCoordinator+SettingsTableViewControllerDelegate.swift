//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import UIKit
import PromiseKit
import NetworkExtension

enum GoVersionCoordinatorError: Error {
    case noEnabledSession
    case noResponse
}

extension AppCoordinator: SettingsTableViewControllerDelegate {
    func goVersionInformation() -> Promise<String> {
        return Promise(resolver: { (resolver) in
            guard let session = self.providerManagers?.first(where: { $0.isEnabled })?.connection as? NETunnelProviderSession else {
                resolver.reject(GoVersionCoordinatorError.noEnabledSession)
                return
            }
            do {
                try session.sendProviderMessage(ExtensionMessage.requestVersion.data, responseHandler: { (data) in
                    guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                        resolver.reject(GoVersionCoordinatorError.noResponse)
                        return
                    }
                    resolver.fulfill(responseString)
                })
            } catch {
                resolver.reject(error)
            }
        })
    }

    func exportTunnels(settingsTableViewController: SettingsTableViewController, sourceView: UIView) {
        self.exportConfigs(sourceView: sourceView)
    }
}
