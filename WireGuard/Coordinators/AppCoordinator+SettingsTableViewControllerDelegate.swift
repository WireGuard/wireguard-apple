//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import UIKit
import PromiseKit
import NetworkExtension

enum GoVersionCoordinatorError: Error {
    case noSession
}

extension AppCoordinator: SettingsTableViewControllerDelegate {
    func goVersionInformation() -> Promise<String> {
        return Promise(resolver: { (resolver) in
            guard let session = self.providerManagers?.first?.connection as? NETunnelProviderSession else {
                resolver.reject(GoVersionCoordinatorError.noSession)
                return
            }
            try session.sendProviderMessage(ExtensionMessage.requestVersion.data, responseHandler: { (data) in
                guard let responseString = String(data: data!, encoding: .utf8) else {
                    return
                }
                resolver.fulfill(responseString)
            })
        })
    }

    func exportTunnels(settingsTableViewController: SettingsTableViewController, sourceView: UIView) {
        self.exportConfigs(sourceView: sourceView)
    }
}
