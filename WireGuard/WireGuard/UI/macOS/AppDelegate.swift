// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        TunnelsManager.create { [weak self] result in
            guard let self = self else { return }
            guard result.isSuccess else { return } // TODO: Show alert

            let tunnelsManager: TunnelsManager = result.value!
            let statusMenu = StatusMenu(tunnelsManager: tunnelsManager)
            self.statusItem = createStatusBarItem(with: statusMenu)

            tunnelsManager.tunnelsListDelegate = statusMenu
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
