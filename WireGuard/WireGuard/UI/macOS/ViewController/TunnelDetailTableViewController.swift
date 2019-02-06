// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Cocoa

class TunnelDetailTableViewController: NSViewController {

    private enum TableViewModelRow {
        case interfaceFieldRow(TunnelViewModel.InterfaceField)
        case peerFieldRow(peer: TunnelViewModel.PeerData, field: TunnelViewModel.PeerField)
        case onDemandRow
        case spacerRow

        func localizedSectionKeyString() -> String {
            switch self {
            case .interfaceFieldRow: return tr("tunnelSectionTitleInterface")
            case .peerFieldRow: return tr("tunnelSectionTitlePeer")
            case .onDemandRow: return ""
            case .spacerRow: return ""
            }
        }

        func isTitleRow() -> Bool {
            switch self {
            case .interfaceFieldRow(let field): return field == .name
            case .peerFieldRow(_, let field): return field == .publicKey
            case .onDemandRow: return true
            case .spacerRow: return false
            }
        }
    }

    static let interfaceFields: [TunnelViewModel.InterfaceField] = [
        .name, .publicKey, .addresses,
        .listenPort, .mtu, .dns
    ]

    static let peerFields: [TunnelViewModel.PeerField] = [
        .publicKey, .preSharedKey, .endpoint,
        .allowedIPs, .persistentKeepAlive,
        .rxBytes, .txBytes, .lastHandshakeTime
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

    let statusCheckbox: NSButton = {
        let checkbox = NSButton()
        checkbox.title = ""
        checkbox.setButtonType(.switch)
        checkbox.state = .off
        checkbox.toolTip = "Toggle status (⌘T)"
        return checkbox
    }()

    let editButton: NSButton = {
        let button = NSButton()
        button.title = tr("Edit")
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        button.toolTip = "Edit tunnel (⌘E)"
        return button
    }()

    let box: NSBox = {
        let box = NSBox()
        box.titlePosition = .noTitle
        box.fillColor = .unemphasizedSelectedContentBackgroundColor
        return box
    }()

    let tunnelsManager: TunnelsManager
    let tunnel: TunnelContainer

    var tunnelViewModel: TunnelViewModel {
        didSet {
            updateTableViewModelRowsBySection()
            updateTableViewModelRows()
        }
    }
    private var tableViewModelRowsBySection = [[(isVisible: Bool, modelRow: TableViewModelRow)]]()
    private var tableViewModelRows = [TableViewModelRow]()

    private var statusObservationToken: AnyObject?
    private var tunnelEditVC: TunnelEditViewController?
    private var reloadRuntimeConfigurationTimer: Timer?

    init(tunnelsManager: TunnelsManager, tunnel: TunnelContainer) {
        self.tunnelsManager = tunnelsManager
        self.tunnel = tunnel
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration)
        super.init(nibName: nil, bundle: nil)
        updateTableViewModelRowsBySection()
        updateTableViewModelRows()
        updateStatus()
        statusObservationToken = tunnel.observe(\TunnelContainer.status) { [weak self] _, _ in
            self?.updateStatus()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        tableView.dataSource = self
        tableView.delegate = self

        statusCheckbox.target = self
        statusCheckbox.action = #selector(statusCheckboxToggled(sender:))

        editButton.target = self
        editButton.action = #selector(handleEditTunnelAction)

        let clipView = NSClipView()
        clipView.documentView = tableView

        let scrollView = NSScrollView()
        scrollView.contentView = clipView // Set contentView before setting drawsBackground
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let containerView = NSView()
        let bottomControlsContainer = NSLayoutGuide()
        containerView.addLayoutGuide(bottomControlsContainer)
        containerView.addSubview(box)
        containerView.addSubview(scrollView)
        containerView.addSubview(statusCheckbox)
        containerView.addSubview(editButton)
        box.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        statusCheckbox.translatesAutoresizingMaskIntoConstraints = false
        editButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.leadingAnchor.constraint(equalTo: bottomControlsContainer.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: bottomControlsContainer.trailingAnchor),
            bottomControlsContainer.heightAnchor.constraint(equalToConstant: 32),
            scrollView.bottomAnchor.constraint(equalTo: bottomControlsContainer.topAnchor),
            bottomControlsContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            statusCheckbox.leadingAnchor.constraint(equalTo: bottomControlsContainer.leadingAnchor),
            bottomControlsContainer.bottomAnchor.constraint(equalTo: statusCheckbox.bottomAnchor, constant: 4),
            editButton.trailingAnchor.constraint(equalTo: bottomControlsContainer.trailingAnchor),
            bottomControlsContainer.bottomAnchor.constraint(equalTo: editButton.bottomAnchor, constant: 4)
        ])

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: box.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: box.trailingAnchor)
        ])

        view = containerView
    }

    func updateTableViewModelRowsBySection() {
        var modelRowsBySection = [[(isVisible: Bool, modelRow: TableViewModelRow)]]()

        var interfaceSection = [(isVisible: Bool, modelRow: TableViewModelRow)]()
        for field in TunnelDetailTableViewController.interfaceFields {
            interfaceSection.append((isVisible: !tunnelViewModel.interfaceData[field].isEmpty, modelRow: .interfaceFieldRow(field)))
        }
        interfaceSection.append((isVisible: true, modelRow: .spacerRow))
        modelRowsBySection.append(interfaceSection)

        for peerData in tunnelViewModel.peersData {
            var peerSection = [(isVisible: Bool, modelRow: TableViewModelRow)]()
            for field in TunnelDetailTableViewController.peerFields {
                peerSection.append((isVisible: !peerData[field].isEmpty, modelRow: .peerFieldRow(peer: peerData, field: field)))
            }
            peerSection.append((isVisible: true, modelRow: .spacerRow))
            modelRowsBySection.append(peerSection)
        }

        var onDemandSection = [(isVisible: Bool, modelRow: TableViewModelRow)]()
        onDemandSection.append((isVisible: true, modelRow: .onDemandRow))
        modelRowsBySection.append(onDemandSection)

        tableViewModelRowsBySection = modelRowsBySection
    }

    func updateTableViewModelRows() {
        tableViewModelRows = tableViewModelRowsBySection.flatMap { $0.filter { $0.isVisible }.map { $0.modelRow } }
    }

    func updateStatus() {
        let statusText: String
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
        statusCheckbox.title = tr(format: "macStatus (%@)", statusText)
        let shouldBeChecked = (tunnel.status != .inactive && tunnel.status != .deactivating)
        let shouldBeEnabled = (tunnel.status == .active || tunnel.status == .inactive)
        statusCheckbox.state = shouldBeChecked ? .on : .off
        statusCheckbox.isEnabled = shouldBeEnabled
        if tunnel.status == .active {
            startUpdatingRuntimeConfiguration()
        } else if tunnel.status == .inactive {
            reloadRuntimeConfiguration()
            stopUpdatingRuntimeConfiguration()
        }
    }

    @objc func handleEditTunnelAction() {
        PrivateDataConfirmation.confirmAccess(to: tr("macViewPrivateData")) { [weak self] in
            guard let self = self else { return }
            let tunnelEditVC = TunnelEditViewController(tunnelsManager: self.tunnelsManager, tunnel: self.tunnel)
            tunnelEditVC.delegate = self
            self.presentAsSheet(tunnelEditVC)
            self.tunnelEditVC = tunnelEditVC
        }
    }

    @objc func handleToggleActiveStatusAction() {
        if tunnel.status == .inactive {
            tunnelsManager.startActivation(of: tunnel)
        } else if tunnel.status == .active {
            tunnelsManager.startDeactivation(of: tunnel)
        }
    }

    @objc func statusCheckboxToggled(sender: AnyObject?) {
        guard let statusCheckbox = sender as? NSButton else { return }
        if statusCheckbox.state == .on {
            tunnelsManager.startActivation(of: tunnel)
        } else if statusCheckbox.state == .off {
            tunnelsManager.startDeactivation(of: tunnel)
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        if let tunnelEditVC = tunnelEditVC {
            dismiss(tunnelEditVC)
        }
        stopUpdatingRuntimeConfiguration()
    }

    func applyTunnelConfiguration(tunnelConfiguration: TunnelConfiguration) {
        // Incorporates changes from tunnelConfiguation. Ignores any changes in peer ordering.
        func sectionChanged<T>(fields: [T], modelRowsInSection: inout [(isVisible: Bool, modelRow: TableViewModelRow)], tableView: NSTableView, rowOffset: Int, changes: [T: TunnelViewModel.ChangeHandlers.FieldChange]) {
            for (index, field) in fields.enumerated() {
                guard let change = changes[field] else { continue }
                let row = modelRowsInSection[0 ..< index].filter { $0.isVisible }.count
                switch change {
                case .added:
                    tableView.insertRows(at: IndexSet(integer: rowOffset + row), withAnimation: .effectFade)
                    modelRowsInSection[index].isVisible = true
                case .removed:
                    tableView.removeRows(at: IndexSet(integer: rowOffset + row), withAnimation: .effectFade)
                    modelRowsInSection[index].isVisible = false
                case .modified:
                    tableView.removeRows(at: IndexSet(integer: rowOffset + row), withAnimation: [])
                    tableView.insertRows(at: IndexSet(integer: rowOffset + row), withAnimation: [])
                }
            }
        }

        var isChanged = false
        let changeHandlers = TunnelViewModel.ChangeHandlers(
            interfaceChanged: { [weak self] changes in
                guard let self = self else { return }
                sectionChanged(fields: TunnelDetailTableViewController.interfaceFields, modelRowsInSection: &self.tableViewModelRowsBySection[0],
                               tableView: self.tableView, rowOffset: 0, changes: changes)
                isChanged = true
            },
            peerChangedAt: { [weak self] peerIndex, changes in
                guard let self = self else { return }
                let sectionIndex = 1 + peerIndex
                let rowOffset = self.tableViewModelRowsBySection[0 ..< sectionIndex].flatMap { $0.filter { $0.isVisible } }.count
                sectionChanged(fields: TunnelDetailTableViewController.peerFields, modelRowsInSection: &self.tableViewModelRowsBySection[sectionIndex],
                               tableView: self.tableView, rowOffset: rowOffset, changes: changes)
                isChanged = true
            },
            peersRemovedAt: { [weak self] peerIndices in
                guard let self = self else { return }
                for peerIndex in peerIndices {
                    let sectionIndex = 1 + peerIndex
                    let rowOffset = self.tableViewModelRowsBySection[0 ..< sectionIndex].flatMap { $0.filter { $0.isVisible } }.count
                    let count = self.tableViewModelRowsBySection[sectionIndex].filter { $0.isVisible }.count
                    self.tableView.removeRows(at: IndexSet(integersIn: rowOffset ..< rowOffset + count), withAnimation: .effectFade)
                    self.tableViewModelRowsBySection.remove(at: sectionIndex)
                }
                isChanged = true
            },
            peersInsertedAt: { [weak self] peerIndices in
                guard let self = self else { return }
                for peerIndex in peerIndices {
                    let peerData = self.tunnelViewModel.peersData[peerIndex]
                    let sectionIndex = 1 + peerIndex
                    let rowOffset = self.tableViewModelRowsBySection[0 ..< sectionIndex].flatMap { $0.filter { $0.isVisible } }.count
                    var modelRowsInSection: [(isVisible: Bool, modelRow: TableViewModelRow)] = TunnelDetailTableViewController.peerFields.map {
                        (isVisible: !peerData[$0].isEmpty, modelRow: .peerFieldRow(peer: peerData, field: $0))
                    }
                    modelRowsInSection.append((isVisible: true, modelRow: .spacerRow))
                    let count = modelRowsInSection.filter { $0.isVisible }.count
                    self.tableView.insertRows(at: IndexSet(integersIn: rowOffset ..< rowOffset + count), withAnimation: .effectFade)
                    self.tableViewModelRowsBySection.insert(modelRowsInSection, at: sectionIndex)
                }
                isChanged = true
            }
        )

        tableView.beginUpdates()
        self.tunnelViewModel.applyConfiguration(other: tunnelConfiguration, changeHandlers: changeHandlers)
        if isChanged {
            updateTableViewModelRows()
        }
        tableView.endUpdates()
    }

    private func reloadRuntimeConfiguration() {
        tunnel.getRuntimeTunnelConfiguration { [weak self] tunnelConfiguration in
            guard let tunnelConfiguration = tunnelConfiguration else { return }
            self?.applyTunnelConfiguration(tunnelConfiguration: tunnelConfiguration)
        }
    }

    func startUpdatingRuntimeConfiguration() {
        reloadRuntimeConfiguration()
        reloadRuntimeConfigurationTimer?.invalidate()
        let reloadTimer = Timer(timeInterval: 1 /* second */, repeats: true) { [weak self] _ in
            self?.reloadRuntimeConfiguration()
        }
        reloadRuntimeConfigurationTimer = reloadTimer
        RunLoop.main.add(reloadTimer, forMode: .common)
    }

    func stopUpdatingRuntimeConfiguration() {
        reloadRuntimeConfiguration()
        reloadRuntimeConfigurationTimer?.invalidate()
        reloadRuntimeConfigurationTimer = nil
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
            let cell: KeyValueRow = tableView.dequeueReusableCell()
            let localizedKeyString = modelRow.isTitleRow() ? modelRow.localizedSectionKeyString() : field.localizedUIString
            cell.key = tr(format: "macFieldKey (%@)", localizedKeyString)
            cell.value = tunnelViewModel.interfaceData[field]
            cell.isKeyInBold = modelRow.isTitleRow()
            return cell
        case .peerFieldRow(let peerData, let field):
            let cell: KeyValueRow = tableView.dequeueReusableCell()
            let localizedKeyString = modelRow.isTitleRow() ? modelRow.localizedSectionKeyString() : field.localizedUIString
            cell.key = tr(format: "macFieldKey (%@)", localizedKeyString)
            if field == .persistentKeepAlive {
                cell.value = tr(format: "tunnelPeerPersistentKeepaliveValue (%@)", peerData[field])
            } else {
                cell.value = peerData[field]
            }
            cell.isKeyInBold = modelRow.isTitleRow()
            return cell
        case .spacerRow:
            return NSView()
        case .onDemandRow:
            let cell: KeyValueRow = tableView.dequeueReusableCell()
            cell.key = tr("macFieldOnDemand")
            cell.value = TunnelViewModel.activateOnDemandDetailText(for: tunnel.activateOnDemandSetting)
            cell.isKeyInBold = true
            return cell
        }
    }
}

extension TunnelDetailTableViewController: TunnelEditViewControllerDelegate {
    func tunnelSaved(tunnel: TunnelContainer) {
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration)
        updateTableViewModelRowsBySection()
        updateTableViewModelRows()
        updateStatus()
        tableView.reloadData()
        self.tunnelEditVC = nil
    }

    func tunnelEditingCancelled() {
        self.tunnelEditVC = nil
    }
}
