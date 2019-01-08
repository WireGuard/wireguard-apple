// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Logger.configureGlobal(withFilePath: FileManager.appLogFileURL?.path)

        TunnelsManager.create { [weak self] result in
            guard let self = self else { return }
            if let error = result.error {
                ErrorPresenter.showErrorAlert(error: error, from: nil)
                return
            }

            let tunnelsManager: TunnelsManager = result.value!
            let statusMenu = StatusMenu(tunnelsManager: tunnelsManager)
            self.statusItem = createStatusBarItem(with: statusMenu)

            tunnelsManager.tunnelsListDelegate = statusMenu
            tunnelsManager.activationDelegate = statusMenu
        }
    }
}

func createStatusBarItem(with statusMenu: StatusMenu) -> NSStatusItem {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let statusBarImage = NSImage(named: "WireGuardMacStatusBarIcon") {
        statusBarImage.isTemplate = true
        statusItem.button?.image = statusBarImage
    }
    statusItem.menu = statusMenu
    return statusItem
}
