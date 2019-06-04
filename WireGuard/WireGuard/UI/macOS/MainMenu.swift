// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

// swiftlint:disable colon

class MainMenu: NSMenu {
    init() {
        super.init(title: "")
        addSubmenu(createApplicationMenu())
        addSubmenu(createFileMenu())
        addSubmenu(createEditMenu())
        addSubmenu(createTunnelMenu())
        addSubmenu(createWindowMenu())
    }

    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addSubmenu(_ menu: NSMenu) {
        let menuItem = self.addItem(withTitle: "", action: nil, keyEquivalent: "")
        self.setSubmenu(menu, for: menuItem)
    }

    private func createApplicationMenu() -> NSMenu {
        let menu = NSMenu()

        let aboutMenuItem = menu.addItem(withTitle: tr("macMenuAbout"),
            action: #selector(AppDelegate.aboutClicked), keyEquivalent: "")
        aboutMenuItem.target = NSApp.delegate

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: tr("macMenuViewLog"),
                     action: #selector(TunnelsListTableViewController.handleViewLogAction), keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        let hideMenuItem = menu.addItem(withTitle: tr("macMenuHideApp"),
                                        action: #selector(NSApplication.hide), keyEquivalent: "h")
        hideMenuItem.target = NSApp
        let hideOthersMenuItem = menu.addItem(withTitle: tr("macMenuHideOtherApps"),
                                              action: #selector(NSApplication.hideOtherApplications), keyEquivalent: "h")
        hideOthersMenuItem.keyEquivalentModifierMask = [.command, .option]
        hideOthersMenuItem.target = NSApp
        let showAllMenuItem = menu.addItem(withTitle: tr("macMenuShowAllApps"),
            action: #selector(NSApplication.unhideAllApplications), keyEquivalent: "")
        showAllMenuItem.target = NSApp

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: tr("macMenuQuit"),
            action: #selector(AppDelegate.confirmAndQuit), keyEquivalent: "q")

        return menu
    }

    private func createFileMenu() -> NSMenu {
        let menu = NSMenu(title: tr("macMenuFile"))

        menu.addItem(withTitle: tr("macMenuAddEmptyTunnel"),
            action: #selector(TunnelsListTableViewController.handleAddEmptyTunnelAction), keyEquivalent: "n")
        menu.addItem(withTitle: tr("macMenuImportTunnels"),
            action: #selector(TunnelsListTableViewController.handleImportTunnelAction), keyEquivalent: "o")

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: tr("macMenuExportTunnels"),
            action: #selector(TunnelsListTableViewController.handleExportTunnelsAction), keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: tr("macMenuCloseWindow"), action: #selector(NSWindow.performClose(_:)), keyEquivalent:"w")

        return menu
    }

    private func createEditMenu() -> NSMenu {
        let menu = NSMenu(title: tr("macMenuEdit"))

        menu.addItem(withTitle: "", action: #selector(UndoActionRespondable.undo(_:)), keyEquivalent:"z")
        menu.addItem(withTitle: "", action: #selector(UndoActionRespondable.redo(_:)), keyEquivalent:"Z")

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: tr("macMenuCut"), action: #selector(NSText.cut(_:)), keyEquivalent:"x")
        menu.addItem(withTitle: tr("macMenuCopy"), action: #selector(NSText.copy(_:)), keyEquivalent:"c")
        menu.addItem(withTitle: tr("macMenuPaste"), action: #selector(NSText.paste(_:)), keyEquivalent:"v")

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: tr("macMenuSelectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent:"a")

        return menu
    }

    private func createTunnelMenu() -> NSMenu {
        let menu = NSMenu(title: tr("macMenuTunnel"))

        menu.addItem(withTitle: tr("macMenuToggleStatus"), action: #selector(TunnelDetailTableViewController.handleToggleActiveStatusAction), keyEquivalent:"t")

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: tr("macMenuEditTunnel"), action: #selector(TunnelDetailTableViewController.handleEditTunnelAction), keyEquivalent:"e")
        menu.addItem(withTitle: tr("macMenuDeleteSelected"), action: #selector(TunnelsListTableViewController.handleRemoveTunnelAction), keyEquivalent: "")

        return menu
    }

    private func createWindowMenu() -> NSMenu {
        let menu = NSMenu(title: tr("macMenuWindow"))

        menu.addItem(withTitle: tr("macMenuMinimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent:"m")
        menu.addItem(withTitle: tr("macMenuZoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent:"")

        menu.addItem(NSMenuItem.separator())

        let fullScreenMenuItem = menu.addItem(withTitle: "", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent:"f")
        fullScreenMenuItem.keyEquivalentModifierMask = [.command, .control]

        return menu
    }
}

@objc protocol UndoActionRespondable {
    func undo(_ sender: AnyObject)
    func redo(_ sender: AnyObject)
}
