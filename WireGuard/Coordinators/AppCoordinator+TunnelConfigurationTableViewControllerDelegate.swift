//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation

extension AppCoordinator: TunnelConfigurationTableViewControllerDelegate {
    func didSave(tunnel: Tunnel, tunnelConfigurationTableViewController: TunnelConfigurationTableViewController) {
        saveTunnel(tunnel)
    }
}
