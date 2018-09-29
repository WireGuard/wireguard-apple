//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation
import NetworkExtension

extension AppCoordinator: TunnelInfoTableViewControllerDelegate {
    func connect(tunnel: Tunnel, tunnelInfoTableViewController: TunnelInfoTableViewController) {
        connect(tunnel: tunnel)
    }

    func disconnect(tunnel: Tunnel, tunnelInfoTableViewController: TunnelInfoTableViewController) {
        disconnect(tunnel: tunnel)
    }

    func status(for tunnel: Tunnel, tunnelInfoTableViewController: TunnelInfoTableViewController) -> NEVPNStatus {
        let session = self.providerManager(for: tunnel)?.connection as? NETunnelProviderSession
        return session?.status ?? .invalid
    }

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
