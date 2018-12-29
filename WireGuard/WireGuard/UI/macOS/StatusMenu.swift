// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

class StatusMenu: NSMenu {

    let tunnelsManager: TunnelsManager
    var firstTunnelMenuItemIndex: Int = 0

    init(tunnelsManager: TunnelsManager) {
        self.tunnelsManager = tunnelsManager
        super.init(title: "WireGuard Status Bar Menu")
        firstTunnelMenuItemIndex = numberOfItems
        let isAdded = addTunnelMenuItems()
        if isAdded {
            addItem(NSMenuItem.separator())
        }
        addTunnelManagementItems()
    }

    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addTunnelMenuItems() -> Bool {
        let numberOfTunnels = tunnelsManager.numberOfTunnels()
        for index in 0 ..< tunnelsManager.numberOfTunnels() {
            let tunnel = tunnelsManager.tunnel(at: index)
            let menuItem = createTunnelMenuItem(for: tunnel)
            addItem(menuItem)
        }
        return numberOfTunnels > 0
    }

    func createTunnelMenuItem(for tunnel: TunnelContainer) -> NSMenuItem {
        let menuItem = NSMenuItem(title: tunnel.name, action: #selector(tunnelClicked(sender:)), keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = tunnel
        return menuItem
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
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["conf", "zip"]
        openPanel.begin { [weak tunnelsManager] response in
            guard let tunnelsManager = tunnelsManager else { return }
            guard response == .OK else { return }
            guard let url = openPanel.url else { return }
            TunnelImporter.importFromFile(url: url, into: tunnelsManager, sourceVC: nil, errorPresenterType: ErrorPresenter.self)
        }
    }
}

extension StatusMenu: TunnelsManagerListDelegate {
    func tunnelAdded(at index: Int) {
        let tunnel = tunnelsManager.tunnel(at: index)
        let menuItem = createTunnelMenuItem(for: tunnel)
        if tunnelsManager.numberOfTunnels() == 1 {
            insertItem(NSMenuItem.separator(), at: firstTunnelMenuItemIndex + index)
        }
        insertItem(menuItem, at: firstTunnelMenuItemIndex + index)
    }

    func tunnelModified(at index: Int) {
        let tunnel = tunnelsManager.tunnel(at: index)
        if let menuItem = item(at: firstTunnelMenuItemIndex + index) {
            menuItem.title = tunnel.name
        }
    }

    func tunnelMoved(from oldIndex: Int, to newIndex: Int) {
        let tunnel = tunnelsManager.tunnel(at: oldIndex)
        let menuItem = createTunnelMenuItem(for: tunnel)
        removeItem(at: firstTunnelMenuItemIndex + oldIndex)
        insertItem(menuItem, at: firstTunnelMenuItemIndex + newIndex)
    }

    func tunnelRemoved(at index: Int) {
        removeItem(at: firstTunnelMenuItemIndex + index)
        if tunnelsManager.numberOfTunnels() == 0 {
            if let firstItem = item(at: firstTunnelMenuItemIndex), firstItem.isSeparatorItem {
                removeItem(at: firstTunnelMenuItemIndex)
            }
        }
    }
}
