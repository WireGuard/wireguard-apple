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
    func exportTunnels(settingsTableViewController: SettingsTableViewController, sourceView: UIView) {
        self.exportConfigs(sourceView: sourceView)
    }
}
