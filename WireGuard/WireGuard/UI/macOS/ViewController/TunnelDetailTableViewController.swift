// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

class TunnelDetailTableViewController: NSViewController {

    private enum TableViewModelRow {
        case interfaceFieldRow(TunnelViewModel.InterfaceField)
        case peerFieldRow(peer: TunnelViewModel.PeerData, field: TunnelViewModel.PeerField)
        case spacerRow

        func localizedSectionKeyString() -> String {
            switch self {
            case .interfaceFieldRow: return tr("tunnelSectionTitleInterface")
            case .peerFieldRow: return tr("tunnelSectionTitlePeer")
            case .spacerRow: return ""
            }
        }

        func isTitleRow() -> Bool {
            switch self {
            case .interfaceFieldRow(let field): return field == .name
            case .peerFieldRow(_, let field): return field == .publicKey
            case .spacerRow: return false
            }
        }
    }

    let interfaceFields: [TunnelViewModel.InterfaceField] = [
        .name, .publicKey, .addresses,
        .listenPort, .mtu, .dns
    ]

    let peerFields: [TunnelViewModel.PeerField] = [
        .publicKey, .preSharedKey, .endpoint,
        .allowedIPs, .persistentKeepAlive
    ]

    let tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TunnelDetail")))
        tableView.headerView = nil
        tableView.rowSizeStyle = .medium
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        return tableView
    }()

    let tunnelsManager: TunnelsManager
    let tunnel: TunnelContainer
    var tunnelViewModel: TunnelViewModel {
        didSet {
            updateTableViewModelRows()
        }
    }
    private var tableViewModelRows = [TableViewModelRow]()

    init(tunnelsManager: TunnelsManager, tunnel: TunnelContainer) {
        self.tunnelsManager = tunnelsManager
        self.tunnel = tunnel
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration)
        super.init(nibName: nil, bundle: nil)
        updateTableViewModelRows()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        tableView.dataSource = self
        tableView.delegate = self

        let clipView = NSClipView()
        clipView.documentView = tableView

        let scrollView = NSScrollView()
        scrollView.contentView = clipView // Set contentView before setting drawsBackground
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        view = scrollView
    }

    func updateTableViewModelRows() {
        tableViewModelRows = []
        for field in interfaceFields where !tunnelViewModel.interfaceData[field].isEmpty {
            tableViewModelRows.append(.interfaceFieldRow(field))
        }
        for peerData in tunnelViewModel.peersData {
            tableViewModelRows.append(.spacerRow)
            for field in peerFields where !peerData[field].isEmpty {
                tableViewModelRows.append(.peerFieldRow(peer: peerData, field: field))
            }
        }
    }
}

extension TunnelDetailTableViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tableViewModelRows.count
    }
}

extension TunnelDetailTableViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let modelRow = tableViewModelRows[row]
        switch modelRow {
        case .interfaceFieldRow(let field):
            let cell: KeyValueCell = tableView.dequeueReusableCell()
            let localizedKeyString = modelRow.isTitleRow() ? modelRow.localizedSectionKeyString() : field.localizedUIString
            cell.key = tr(format: "macDetailFieldKey (%@)", localizedKeyString)
            cell.value = tunnelViewModel.interfaceData[field]
            cell.isKeyInBold = modelRow.isTitleRow()
            return cell
        case .peerFieldRow(let peerData, let field):
            let cell: KeyValueCell = tableView.dequeueReusableCell()
            let localizedKeyString = modelRow.isTitleRow() ? modelRow.localizedSectionKeyString() : field.localizedUIString
            cell.key = tr(format: "macDetailFieldKey (%@)", localizedKeyString)
            cell.value = peerData[field]
            cell.isKeyInBold = modelRow.isTitleRow()
            return cell
        case .spacerRow:
            return NSView()
        }
    }
}
