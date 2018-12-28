// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

class StatusMenu: NSMenu {

    let tunnelsManager: TunnelsManager

    init(tunnelsManager: TunnelsManager) {
        self.tunnelsManager = tunnelsManager
        super.init(title: "WireGuard Status Bar Menu")
        addTunnelMenuItems()
        addItem(NSMenuItem.separator())
        addTunnelManagementItems()
    }

    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addTunnelMenuItems() {
        for index in 0 ..< tunnelsManager.numberOfTunnels() {
            let tunnel = tunnelsManager.tunnel(at: index)
            let menuItem = NSMenuItem(title: tunnel.name, action: #selector(tunnelClicked(sender:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = tunnel
            addItem(menuItem)
        }
    }

    @objc func tunnelClicked(sender: AnyObject) {
        guard let tunnel = sender.representedObject as? TunnelContainer else { return }
        print("Tunnel \(tunnel.name) clicked")
    }

    func addTunnelManagementItems() {
        let manageItem = NSMenuItem(title: tr("macMenuManageTunnels"), action: #selector(manageTunnelsClicked), keyEquivalent: "")
        manageItem.target = self
        addItem(manageItem)
        let importItem = NSMenuItem(title: tr("macMenuImportTunnels"), action: #selector(importTunnelsClicked), keyEquivalent: "")
        importItem.target = self
        addItem(importItem)
    }

    @objc func manageTunnelsClicked() {
        print("Unimplemented")
    }

    @objc func importTunnelsClicked() {
        print("Unimplemented")
    }
}
