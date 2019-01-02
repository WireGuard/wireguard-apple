// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

protocol TunnelsListTableViewControllerDelegate: class {
    func tunnelSelected(tunnel: TunnelContainer)
    func tunnelListEmpty()
}

class TunnelsListTableViewController: NSViewController {

    let tunnelsManager: TunnelsManager
    weak var delegate: TunnelsListTableViewControllerDelegate?

    let tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TunnelsList")))
        tableView.headerView = nil
        tableView.rowSizeStyle = .medium
        return tableView
    }()

    let buttonBar: NSSegmentedControl = {
        let addButtonImage = NSImage(named: NSImage.addTemplateName)!
        let removeButtonImage = NSImage(named: NSImage.removeTemplateName)!
        let actionButtonImage = NSImage(named: NSImage.actionTemplateName)!
        let buttonBar = NSSegmentedControl(images: [addButtonImage, removeButtonImage, actionButtonImage],
                                           trackingMode: .momentary, target: nil, action: #selector(buttonBarClicked(sender:)))
        buttonBar.segmentStyle = .smallSquare
        buttonBar.segmentDistribution = .fit
        buttonBar.setShowsMenuIndicator(true, forSegment: 0)
        buttonBar.setShowsMenuIndicator(false, forSegment: 1)
        buttonBar.setShowsMenuIndicator(true, forSegment: 2)
        return buttonBar
    }()

    let addMenu: NSMenu = {
        let addMenu = NSMenu(title: "TunnelsListAdd")
        addMenu.addItem(withTitle: "Add empty tunnel", action: #selector(addEmptyTunnelClicked), keyEquivalent: "")
        addMenu.addItem(withTitle: "Import tunnel(s) from file...", action: #selector(importTunnelClicked), keyEquivalent: "")
        return addMenu
    }()

    let actionMenu: NSMenu = {
        let actionMenu = NSMenu(title: "TunnelsListAction")
        actionMenu.addItem(withTitle: "Export log to file", action: #selector(exportLogClicked), keyEquivalent: "")
        actionMenu.addItem(withTitle: "Export tunnels to zip", action: #selector(exportTunnelsClicked), keyEquivalent: "")
        return actionMenu
    }()

    init(tunnelsManager: TunnelsManager) {
        self.tunnelsManager = tunnelsManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        tableView.dataSource = self
        tableView.delegate = self

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let clipView = NSClipView()
        clipView.documentView = tableView
        scrollView.contentView = clipView

        let fillerButton = FillerButton()

        let containerView = NSView()
        containerView.addSubview(scrollView)
        containerView.addSubview(buttonBar)
        containerView.addSubview(fillerButton)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        fillerButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: buttonBar.topAnchor, constant: 1),
            containerView.leadingAnchor.constraint(equalTo: buttonBar.leadingAnchor),
            containerView.bottomAnchor.constraint(equalTo: buttonBar.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: fillerButton.topAnchor, constant: 1),
            containerView.bottomAnchor.constraint(equalTo: fillerButton.bottomAnchor),
            buttonBar.trailingAnchor.constraint(equalTo: fillerButton.leadingAnchor, constant: 1),
            fillerButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])

        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])

        buttonBar.target = self
        addMenu.items.forEach { $0.target = self }
        actionMenu.items.forEach { $0.target = self }

        view = containerView
    }

    @objc func buttonBarClicked(sender: AnyObject?) {
        guard let buttonBar = sender as? NSSegmentedControl else { return }
        // We have to resort to explicitly showing the menu instead of using NSSegmentedControl.setMenu()
        // because we have a mix of menu and non-menu segments.
        // See: http://openradar.appspot.com/radar?id=61419
        if buttonBar.selectedSegment == 0 {
            let segmentBottomLeft = NSPoint(x: 0, y: buttonBar.bounds.height + 2)
            addMenu.popUp(positioning: nil, at: segmentBottomLeft, in: buttonBar)
        } else if buttonBar.selectedSegment == 1 {
            removeTunnelClicked()
        } else if buttonBar.selectedSegment == 2 {
            let segmentBottomLeft = NSPoint(x: buttonBar.bounds.width * 0.66, y: buttonBar.bounds.height + 2)
            actionMenu.popUp(positioning: nil, at: segmentBottomLeft, in: buttonBar)
        }
    }

    @objc func addEmptyTunnelClicked() {
        print("addEmptyTunnelClicked")
    }

    @objc func importTunnelClicked() {
        print("importTunnelClicked")
    }

    @objc func removeTunnelClicked() {
        print("removeTunnelClicked")
    }

    @objc func exportLogClicked() {
        print("exportLogClicked")
    }
    @objc func exportTunnelsClicked() {
        print("exportTunnelsClicked")
    }
}

extension TunnelsListTableViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tunnelsManager.numberOfTunnels()
    }
}

extension TunnelsListTableViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell: TunnelListCell = tableView.dequeueReusableCell()
        cell.tunnel = tunnelsManager.tunnel(at: row)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow >= 0 else {
            if tunnelsManager.numberOfTunnels() == 0 {
                delegate?.tunnelListEmpty()
            }
            return
        }
        let selectedTunnel = tunnelsManager.tunnel(at: tableView.selectedRow)
        delegate?.tunnelSelected(tunnel: selectedTunnel)
    }
}

class FillerButton: NSButton {
    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    init() {
        super.init(frame: CGRect.zero)
        title = ""
        bezelStyle = .smallSquare
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        // Eat mouseDown event, so that the button looks enabled but is unresponsive
    }
}
