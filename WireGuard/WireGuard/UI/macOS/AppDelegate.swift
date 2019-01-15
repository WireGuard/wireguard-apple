// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItemController: StatusItemController?
    var currentTunnelStatusObserver: AnyObject?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Logger.configureGlobal(withFilePath: FileManager.appLogFileURL?.path)

        TunnelsManager.create { [weak self] result in
            guard let self = self else { return }
            if let error = result.error {
                ErrorPresenter.showErrorAlert(error: error, from: nil)
                return
            }

            let tunnelsManager: TunnelsManager = result.value!
            let statusItemController = StatusItemController()

            let statusMenu = StatusMenu(tunnelsManager: tunnelsManager)

            statusItemController.statusItem.menu = statusMenu
            statusItemController.currentTunnel = statusMenu.currentTunnel
            self.currentTunnelStatusObserver = statusMenu.observe(\.currentTunnel) { statusMenu, _ in
                statusItemController.currentTunnel = statusMenu.currentTunnel
            }
            self.statusItemController = statusItemController

            tunnelsManager.tunnelsListDelegate = statusMenu
            tunnelsManager.activationDelegate = statusMenu
        }
    }
}
