// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

class TunnelsListTableViewController: NSViewController {

    let tunnelsManager: TunnelsManager

    let tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TunnelsList")))
        tableView.headerView = nil
        tableView.rowSizeStyle = .medium
        return tableView
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

        let clipView = NSClipView()
        clipView.documentView = tableView
        scrollView.contentView = clipView

        self.view = scrollView
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
}
