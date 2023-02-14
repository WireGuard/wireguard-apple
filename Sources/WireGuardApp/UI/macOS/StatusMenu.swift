// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

protocol StatusMenuWindowDelegate: AnyObject {
    func showManageTunnelsWindow(completion: ((NSWindow?) -> Void)?)
}

class StatusMenu: NSMenu {

    let tunnelsManager: TunnelsManager

    var statusMenuItem: NSMenuItem?
    var networksMenuItem: NSMenuItem?
    var deactivateMenuItem: NSMenuItem?

    private let tunnelsBreakdownMenu = NSMenu()
    private let tunnelsMenuItem = NSMenuItem(title: tr("macTunnelsMenuTitle"), action: nil, keyEquivalent: "")
    private let tunnelsMenuSeparatorItem = NSMenuItem.separator()

    private var firstTunnelMenuItemIndex = 0
    private var numberOfTunnelMenuItems = 0
    private var tunnelsPresentationStyle = StatusMenuTunnelsPresentationStyle.inline

    var currentTunnel: TunnelContainer? {
        didSet {
            updateStatusMenuItems(with: currentTunnel)
        }
    }
    weak var windowDelegate: StatusMenuWindowDelegate?

    init(tunnelsManager: TunnelsManager) {
        self.tunnelsManager = tunnelsManager

        super.init(title: tr("macMenuTitle"))

        addStatusMenuItems()
        addItem(NSMenuItem.separator())

        tunnelsMenuItem.submenu = tunnelsBreakdownMenu
        addItem(tunnelsMenuItem)

        firstTunnelMenuItemIndex = numberOfItems
        populateInitialTunnelMenuItems()

        addItem(tunnelsMenuSeparatorItem)

        addTunnelManagementItems()
        addItem(NSMenuItem.separator())
        addApplicationItems()
    }

    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addStatusMenuItems() {
        let statusTitle = tr(format: "macStatus (%@)", tr("tunnelStatusInactive"))
        let statusMenuItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        addItem(statusMenuItem)
        let networksMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        networksMenuItem.isEnabled = false
        networksMenuItem.isHidden = true
        addItem(networksMenuItem)
        let deactivateMenuItem = NSMenuItem(title: tr("macToggleStatusButtonDeactivate"), action: #selector(deactivateClicked), keyEquivalent: "")
        deactivateMenuItem.target = self
        deactivateMenuItem.isHidden = true
        addItem(deactivateMenuItem)
        self.statusMenuItem = statusMenuItem
        self.networksMenuItem = networksMenuItem
        self.deactivateMenuItem = deactivateMenuItem
    }

    func updateStatusMenuItems(with tunnel: TunnelContainer?) {
        guard let statusMenuItem = statusMenuItem, let networksMenuItem = networksMenuItem, let deactivateMenuItem = deactivateMenuItem else { return }
        guard let tunnel = tunnel else {
            statusMenuItem.title = tr(format: "macStatus (%@)", tr("tunnelStatusInactive"))
            networksMenuItem.title = ""
            networksMenuItem.isHidden = true
            deactivateMenuItem.isHidden = true
            return
        }
        var statusText: String

        switch tunnel.status {
        case .waiting:
            statusText = tr("tunnelStatusWaiting")
        case .inactive:
            statusText = tr("tunnelStatusInactive")
        case .activating:
            statusText = tr("tunnelStatusActivating")
        case .active:
            statusText = tr("tunnelStatusActive")
        case .deactivating:
            statusText = tr("tunnelStatusDeactivating")
        case .reasserting:
            statusText = tr("tunnelStatusReasserting")
        case .restarting:
            statusText = tr("tunnelStatusRestarting")
        }

        statusMenuItem.title = tr(format: "macStatus (%@)", statusText)

        if tunnel.status == .inactive {
            networksMenuItem.title = ""
            networksMenuItem.isHidden = true
        } else {
            let allowedIPs = tunnel.tunnelConfiguration?.peers.flatMap { $0.allowedIPs }.map { $0.stringRepresentation }.joined(separator: ", ") ?? ""
            if !allowedIPs.isEmpty {
                networksMenuItem.title = tr(format: "macMenuNetworks (%@)", allowedIPs)
            } else {
                networksMenuItem.title = tr("macMenuNetworksNone")
            }
            networksMenuItem.isHidden = false
        }
        deactivateMenuItem.isHidden = tunnel.status != .active
    }

    func addTunnelManagementItems() {
        let manageItem = NSMenuItem(title: tr("macMenuManageTunnels"), action: #selector(manageTunnelsClicked), keyEquivalent: "")
        manageItem.target = self
        addItem(manageItem)
        let importItem = NSMenuItem(title: tr("macMenuImportTunnels"), action: #selector(importTunnelsClicked), keyEquivalent: "")
        importItem.target = self
        addItem(importItem)
    }

    func addApplicationItems() {
        let aboutItem = NSMenuItem(title: tr("macMenuAbout"), action: #selector(AppDelegate.aboutClicked), keyEquivalent: "")
        aboutItem.target = NSApp.delegate
        addItem(aboutItem)
        let quitItem = NSMenuItem(title: tr("macMenuQuit"), action: #selector(AppDelegate.quit), keyEquivalent: "")
        quitItem.target = NSApp.delegate
        addItem(quitItem)
    }

    @objc func deactivateClicked() {
        if let currentTunnel = currentTunnel {
            tunnelsManager.startDeactivation(of: currentTunnel)
        }
    }

    @objc func tunnelClicked(sender: AnyObject) {
        guard let tunnelMenuItem = sender as? TunnelMenuItem else { return }
        let tunnel = tunnelMenuItem.tunnel
        if tunnel.hasOnDemandRules {
            let turnOn = !tunnel.isActivateOnDemandEnabled
            tunnelsManager.setOnDemandEnabled(turnOn, on: tunnel) { error in
                if error == nil && !turnOn {
                    self.tunnelsManager.startDeactivation(of: tunnel)
                }
            }
        } else {
            if tunnel.status == .inactive {
                tunnelsManager.startActivation(of: tunnel)
            } else if tunnel.status == .active {
                tunnelsManager.startDeactivation(of: tunnel)
            }
        }
    }

    @objc func manageTunnelsClicked() {
        windowDelegate?.showManageTunnelsWindow(completion: nil)
    }

    @objc func importTunnelsClicked() {
        windowDelegate?.showManageTunnelsWindow { [weak self] manageTunnelsWindow in
            guard let self = self else { return }
            guard let manageTunnelsWindow = manageTunnelsWindow else { return }
            ImportPanelPresenter.presentImportPanel(tunnelsManager: self.tunnelsManager,
                                                    sourceVC: manageTunnelsWindow.contentViewController)
        }
    }
}

extension StatusMenu {
    func insertTunnelMenuItem(for tunnel: TunnelContainer, at tunnelIndex: Int) {
        let nextNumberOfTunnels = numberOfTunnelMenuItems + 1

        guard !reparentTunnelMenuItems(nextNumberOfTunnels: nextNumberOfTunnels) else {
            return
        }

        let menuItem = makeTunnelItem(tunnel: tunnel)
        switch tunnelsPresentationStyle {
        case .submenu:
            tunnelsBreakdownMenu.insertItem(menuItem, at: tunnelIndex)
        case .inline:
            insertItem(menuItem, at: firstTunnelMenuItemIndex + tunnelIndex)
        }

        numberOfTunnelMenuItems = nextNumberOfTunnels
        updateTunnelsMenuItemVisibility()
    }

    func removeTunnelMenuItem(at tunnelIndex: Int) {
        let nextNumberOfTunnels = numberOfTunnelMenuItems - 1

        guard !reparentTunnelMenuItems(nextNumberOfTunnels: nextNumberOfTunnels) else {
            return
        }

        switch tunnelsPresentationStyle {
        case .submenu:
            tunnelsBreakdownMenu.removeItem(at: tunnelIndex)
        case .inline:
            removeItem(at: firstTunnelMenuItemIndex + tunnelIndex)
        }

        numberOfTunnelMenuItems = nextNumberOfTunnels
        updateTunnelsMenuItemVisibility()
    }

    func moveTunnelMenuItem(from oldTunnelIndex: Int, to newTunnelIndex: Int) {
        let tunnel = tunnelsManager.tunnel(at: newTunnelIndex)
        let menuItem = makeTunnelItem(tunnel: tunnel)

        switch tunnelsPresentationStyle {
        case .submenu:
            tunnelsBreakdownMenu.removeItem(at: oldTunnelIndex)
            tunnelsBreakdownMenu.insertItem(menuItem, at: newTunnelIndex)
        case .inline:
            removeItem(at: firstTunnelMenuItemIndex + oldTunnelIndex)
            insertItem(menuItem, at: firstTunnelMenuItemIndex + newTunnelIndex)
        }
    }

    private func makeTunnelItem(tunnel: TunnelContainer) -> TunnelMenuItem {
        let menuItem = TunnelMenuItem(tunnel: tunnel, action: #selector(tunnelClicked(sender:)))
        menuItem.target = self
        menuItem.isHidden = !tunnel.isTunnelAvailableToUser
        return menuItem
    }

    private func populateInitialTunnelMenuItems() {
        let numberOfTunnels = tunnelsManager.numberOfTunnels()
        let initialStyle = tunnelsPresentationStyle.preferredPresentationStyle(numberOfTunnels: numberOfTunnels)

        tunnelsPresentationStyle = initialStyle
        switch initialStyle {
        case .inline:
            numberOfTunnelMenuItems = addTunnelMenuItems(into: self, at: firstTunnelMenuItemIndex)
        case .submenu:
            numberOfTunnelMenuItems = addTunnelMenuItems(into: tunnelsBreakdownMenu, at: 0)
        }

        updateTunnelsMenuItemVisibility()
    }

    private func reparentTunnelMenuItems(nextNumberOfTunnels: Int) -> Bool {
        let nextStyle = tunnelsPresentationStyle.preferredPresentationStyle(numberOfTunnels: nextNumberOfTunnels)

        switch (tunnelsPresentationStyle, nextStyle) {
        case (.inline, .submenu):
            tunnelsPresentationStyle = nextStyle
            for index in (0..<numberOfTunnelMenuItems).reversed() {
                removeItem(at: firstTunnelMenuItemIndex + index)
            }
            numberOfTunnelMenuItems = addTunnelMenuItems(into: tunnelsBreakdownMenu, at: 0)
            updateTunnelsMenuItemVisibility()
            return true

        case (.submenu, .inline):
            tunnelsPresentationStyle = nextStyle
            tunnelsBreakdownMenu.removeAllItems()
            numberOfTunnelMenuItems = addTunnelMenuItems(into: self, at: firstTunnelMenuItemIndex)
            updateTunnelsMenuItemVisibility()
            return true

        case (.submenu, .submenu), (.inline, .inline):
            return false
        }
    }

    private func addTunnelMenuItems(into menu: NSMenu, at startIndex: Int) -> Int {
        let numberOfTunnels = tunnelsManager.numberOfTunnels()
        for tunnelIndex in 0..<numberOfTunnels {
            let tunnel = tunnelsManager.tunnel(at: tunnelIndex)
            let menuItem = makeTunnelItem(tunnel: tunnel)
            menu.insertItem(menuItem, at: startIndex + tunnelIndex)
        }
        return numberOfTunnels
    }

    private func updateTunnelsMenuItemVisibility() {
        switch tunnelsPresentationStyle {
        case .inline:
            tunnelsMenuItem.isHidden = true
        case .submenu:
            tunnelsMenuItem.isHidden = false
        }
        tunnelsMenuSeparatorItem.isHidden = numberOfTunnelMenuItems == 0
    }
}

class TunnelMenuItem: NSMenuItem {

    var tunnel: TunnelContainer

    private var statusObservationToken: AnyObject?
    private var nameObservationToken: AnyObject?
    private var isOnDemandEnabledObservationToken: AnyObject?

    init(tunnel: TunnelContainer, action selector: Selector?) {
        self.tunnel = tunnel
        super.init(title: tunnel.name, action: selector, keyEquivalent: "")
        updateStatus()
        let statusObservationToken = tunnel.observe(\.status) { [weak self] _, _ in
            self?.updateStatus()
        }
        updateTitle()
        let nameObservationToken = tunnel.observe(\TunnelContainer.name) { [weak self] _, _ in
            self?.updateTitle()
        }
        let isOnDemandEnabledObservationToken = tunnel.observe(\.isActivateOnDemandEnabled) { [weak self] _, _ in
            self?.updateTitle()
            self?.updateStatus()
        }
        self.statusObservationToken = statusObservationToken
        self.isOnDemandEnabledObservationToken = isOnDemandEnabledObservationToken
        self.nameObservationToken = nameObservationToken
    }

    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTitle() {
        if tunnel.isActivateOnDemandEnabled {
            title = tunnel.name + " (On-Demand)"
        } else {
            title = tunnel.name
        }
    }

    func updateStatus() {
        if tunnel.isActivateOnDemandEnabled {
            state = (tunnel.status == .inactive || tunnel.status == .deactivating) ? .mixed : .on
        } else {
            state = (tunnel.status == .inactive || tunnel.status == .deactivating) ? .off : .on
        }
    }
}

private enum StatusMenuTunnelsPresentationStyle {
    case inline
    case submenu

    func preferredPresentationStyle(numberOfTunnels: Int) -> StatusMenuTunnelsPresentationStyle {
        let maxInlineTunnels = 10

        if case .inline = self, numberOfTunnels > maxInlineTunnels {
            return .submenu
        } else if case .submenu = self, numberOfTunnels <= maxInlineTunnels {
            return .inline
        } else {
            return self
        }
    }
}
