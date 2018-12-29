// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

class StatusMenu: NSMenu {

    let tunnelsManager: TunnelsManager
    var tunnelStatusObservers = [AnyObject]()

    var firstTunnelMenuItemIndex: Int = 0
    var numberOfTunnelMenuItems: Int = 0

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
            insertTunnelMenuItem(for: tunnel, at: numberOfTunnelMenuItems)
        }
        return numberOfTunnels > 0
    }

    func addTunnelManagementItems() {
        let manageItem = NSMenuItem(title: tr("macMenuManageTunnels"), action: #selector(manageTunnelsClicked), keyEquivalent: "")
        manageItem.target = self
        addItem(manageItem)
        let importItem = NSMenuItem(title: tr("macMenuImportTunnels"), action: #selector(importTunnelsClicked), keyEquivalent: "")
        importItem.target = self
        addItem(importItem)
    }

    @objc func tunnelClicked(sender: AnyObject) {
        guard let tunnelMenuItem = sender as? NSMenuItem else { return }
        guard let tunnel = tunnelMenuItem.representedObject as? TunnelContainer else { return }
        if tunnelMenuItem.state == .off {
            tunnelsManager.startActivation(of: tunnel)
        } else {
            tunnelsManager.startDeactivation(of: tunnel)
        }
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

extension StatusMenu {
    func insertTunnelMenuItem(for tunnel: TunnelContainer, at tunnelIndex: Int) {
        let menuItem = NSMenuItem(title: tunnel.name, action: #selector(tunnelClicked(sender:)), keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = tunnel
        updateTunnelMenuItem(menuItem)
        let statusObservationToken = tunnel.observe(\.status) { _, _ in
            updateTunnelMenuItem(menuItem)
        }
        tunnelStatusObservers.insert(statusObservationToken, at: tunnelIndex)
        insertItem(menuItem, at: firstTunnelMenuItemIndex + tunnelIndex)
        if numberOfTunnelMenuItems == 0 {
            insertItem(NSMenuItem.separator(), at: firstTunnelMenuItemIndex + tunnelIndex + 1)
        }
        numberOfTunnelMenuItems += 1
    }

    func removeTunnelMenuItem(at tunnelIndex: Int) {
        removeItem(at: firstTunnelMenuItemIndex + tunnelIndex)
        tunnelStatusObservers.remove(at: tunnelIndex)
        numberOfTunnelMenuItems -= 1
        if numberOfTunnelMenuItems == 0 {
            if let firstItem = item(at: firstTunnelMenuItemIndex), firstItem.isSeparatorItem {
                removeItem(at: firstTunnelMenuItemIndex)
            }
        }
    }

    func moveTunnelMenuItem(from oldTunnelIndex: Int, to newTunnelIndex: Int) {
        let oldMenuItem = item(at: firstTunnelMenuItemIndex + oldTunnelIndex)!
        let oldMenuItemTitle = oldMenuItem.title
        let oldMenuItemTunnel = oldMenuItem.representedObject
        removeItem(at: firstTunnelMenuItemIndex + oldTunnelIndex)
        let menuItem = NSMenuItem(title: oldMenuItemTitle, action: #selector(tunnelClicked(sender:)), keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = oldMenuItemTunnel
        insertItem(menuItem, at: firstTunnelMenuItemIndex + newTunnelIndex)
        let statusObserver = tunnelStatusObservers.remove(at: oldTunnelIndex)
        tunnelStatusObservers.insert(statusObserver, at: newTunnelIndex)
    }
}

private func updateTunnelMenuItem(_ tunnelMenuItem: NSMenuItem) {
    guard let tunnel = tunnelMenuItem.representedObject as? TunnelContainer else { return }
    tunnelMenuItem.title = tunnel.name
    let shouldShowCheckmark = (tunnel.status != .inactive && tunnel.status != .deactivating)
    tunnelMenuItem.state = shouldShowCheckmark ? .on : .off
}

extension StatusMenu: TunnelsManagerListDelegate {
    func tunnelAdded(at index: Int) {
        let tunnel = tunnelsManager.tunnel(at: index)
        insertTunnelMenuItem(for: tunnel, at: index)
    }

    func tunnelModified(at index: Int) {
        if let tunnelMenuItem = item(at: firstTunnelMenuItemIndex + index) {
            updateTunnelMenuItem(tunnelMenuItem)
        }
    }

    func tunnelMoved(from oldIndex: Int, to newIndex: Int) {
        moveTunnelMenuItem(from: oldIndex, to: newIndex)
    }

    func tunnelRemoved(at index: Int) {
        removeTunnelMenuItem(at: index)
    }
}
