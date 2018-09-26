//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation

extension AppCoordinator: TunnelInfoTableViewControllerDelegate {
    func configure(tunnel: Tunnel, tunnelInfoTableViewController: TunnelInfoTableViewController) {
        print("configure tunnel \(tunnel)")
        let editContext = persistentContainer.newBackgroundContext()
        var backgroundTunnel: Tunnel?
        editContext.performAndWait {
            backgroundTunnel = editContext.object(with: tunnel.objectID) as? Tunnel
        }

        showTunnelConfigurationViewController(tunnel: backgroundTunnel, context: editContext)
    }

}
