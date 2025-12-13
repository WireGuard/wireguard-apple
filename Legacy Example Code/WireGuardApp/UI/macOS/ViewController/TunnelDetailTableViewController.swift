// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class TunnelDetailTableViewController: NSViewController {

    private enum TableViewModelRow {
        case interfaceFieldRow(TunnelViewModel.InterfaceField)
        case peerFieldRow(peer: TunnelViewModel.PeerData, field: TunnelViewModel.PeerField)
        case onDemandRow
        case onDemandSSIDRow
        case spacerRow

        func localizedSectionKeyString() -> String {
            switch self {
            case .interfaceFieldRow: return tr("tunnelSectionTitleInterface")
            case .peerFieldRow: return tr("tunnelSectionTitlePeer")
            case .onDemandRow: return tr("macFieldOnDemand")
            case .onDemandSSIDRow: return ""
            case .spacerRow: return ""
            }
        }

        func isTitleRow() -> Bool {
            switch self {
            case .interfaceFieldRow(let field): return field == .name
            case .peerFieldRow(_, let field): return field == .publicKey
            case .onDemandRow: return true
            case .onDemandSSIDRow: return false
            case .spacerRow: return false
            }
        }
    }

    static let interfaceFields: [TunnelViewModel.InterfaceField] = [
        .name, .status, .publicKey, .addresses,
        .listenPort, .mtu, .dns, .toggleStatus
    ]

    static let peerFields: [TunnelViewModel.PeerField] = [
        .publicKey, .preSharedKey, .endpoint,
        .allowedIPs, .persistentKeepAlive,
        .rxBytes, .txBytes, .lastHandshakeTime
    ]

    static let onDemandFields: [ActivateOnDemandViewModel.OnDemandField] = [
        .onDemand, .ssid
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

    let editButton: NSButton = {
        let button = NSButton()
        button.title = tr("macButtonEdit")
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        button.toolTip = tr("macToolTipEditTunnel")
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

    var onDemandViewModel: ActivateOnDemandViewModel

    private var tableViewModelRowsBySection = [[(isVisible: Bool, modelRow: TableViewModelRow)]]()
    private var tableViewModelRows = [TableViewModelRow]()

    private var statusObservationToken: AnyObject?
    private var tunnelEditVC: TunnelEditViewController?
    private var reloadRuntimeConfigurationTimer: Timer?

    init(tunnelsManager: TunnelsManager, tunnel: TunnelContainer) {
        self.tunnelsManager = tunnelsManager
        self.tunnel = tunnel
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration)
        onDemandViewModel = ActivateOnDemandViewModel(tunnel: tunnel)
        super.init(nibName: nil, bundle: nil)
        updateTableViewModelRowsBySection()
        updateTableViewModelRows()
        statusObservationToken = tunnel.observe(\TunnelContainer.status) { [weak self] _, _ in
            guard let self = self else { return }
            if tunnel.status == .active {
                self.startUpdatingRuntimeConfiguration()
            } else if tunnel.status == .inactive {
                self.reloadRuntimeConfiguration()
                self.stopUpdatingRuntimeConfiguration()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        tableView.dataSource = self
        tableView.delegate = self

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
        containerView.addSubview(editButton)
        box.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
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
            editButton.trailingAnchor.constraint(equalTo: bottomControlsContainer.trailingAnchor),
            bottomControlsContainer.bottomAnchor.constraint(equalTo: editButton.bottomAnchor, constant: 0)
        ])

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: box.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: box.trailingAnchor)
        ])

        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])

        view = containerView
    }

    func updateTableViewModelRowsBySection() {
        var modelRowsBySection = [[(isVisible: Bool, modelRow: TableViewModelRow)]]()

        var interfaceSection = [(isVisible: Bool, modelRow: TableViewModelRow)]()
        for field in TunnelDetailTableViewController.interfaceFields {
            let isStatus = field == .status || field == .toggleStatus
            let isEmpty = tunnelViewModel.interfaceData[field].isEmpty
            interfaceSection.append((isVisible: isStatus || !isEmpty, modelRow: .interfaceFieldRow(field)))
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
        if onDemandViewModel.isWiFiInterfaceEnabled {
            onDemandSection.append((isVisible: true, modelRow: .onDemandSSIDRow))
        }
        modelRowsBySection.append(onDemandSection)

        tableViewModelRowsBySection = modelRowsBySection
    }

    func updateTableViewModelRows() {
        tableViewModelRows = tableViewModelRowsBySection.flatMap { $0.filter { $0.isVisible }.map { $0.modelRow } }
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
        if tunnel.hasOnDemandRules {
            let turnOn = !tunnel.isActivateOnDemandEnabled
            tunnelsManager.setOnDemandEnabled(turnOn, on: tunnel) { error in
                if error == nil && !turnOn {
                    self.tunnelsManager.startDeactivation(of: self.tunnel)
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

    override func viewWillAppear() {
        if tunnel.status == .active {
            startUpdatingRuntimeConfiguration()
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

        let tableView = self.tableView

        func handleSectionFieldsModified<T>(fields: [T], modelRowsInSection: [(isVisible: Bool, modelRow: TableViewModelRow)], rowOffset: Int, changes: [T: TunnelViewModel.Changes.FieldChange]) {
            var modifiedRowIndices = IndexSet()
            for (index, field) in fields.enumerated() {
                guard let change = changes[field] else { continue }
                if case .modified = change {
                    let row = modelRowsInSection[0 ..< index].filter { $0.isVisible }.count
                    modifiedRowIndices.insert(rowOffset + row)
                }
            }
            if !modifiedRowIndices.isEmpty {
                tableView.reloadData(forRowIndexes: modifiedRowIndices, columnIndexes: IndexSet(integer: 0))
            }
        }

        func handleSectionFieldsAddedOrRemoved<T>(fields: [T], modelRowsInSection: inout [(isVisible: Bool, modelRow: TableViewModelRow)], rowOffset: Int, changes: [T: TunnelViewModel.Changes.FieldChange]) {
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
                    break
                }
            }
        }

        let changes = self.tunnelViewModel.applyConfiguration(other: tunnelConfiguration)

        if !changes.interfaceChanges.isEmpty {
            handleSectionFieldsModified(fields: TunnelDetailTableViewController.interfaceFields,
                                        modelRowsInSection: self.tableViewModelRowsBySection[0],
                                        rowOffset: 0, changes: changes.interfaceChanges)
        }
        for (peerIndex, peerChanges) in changes.peerChanges {
            let sectionIndex = 1 + peerIndex
            let rowOffset = self.tableViewModelRowsBySection[0 ..< sectionIndex].flatMap { $0.filter { $0.isVisible } }.count
            handleSectionFieldsModified(fields: TunnelDetailTableViewController.peerFields,
                                        modelRowsInSection: self.tableViewModelRowsBySection[sectionIndex],
                                        rowOffset: rowOffset, changes: peerChanges)
        }

        let isAnyInterfaceFieldAddedOrRemoved = changes.interfaceChanges.contains { $0.value == .added || $0.value == .removed }
        let isAnyPeerFieldAddedOrRemoved = changes.peerChanges.contains { $0.changes.contains { $0.value == .added || $0.value == .removed } }

        if isAnyInterfaceFieldAddedOrRemoved || isAnyPeerFieldAddedOrRemoved || !changes.peersRemovedIndices.isEmpty || !changes.peersInsertedIndices.isEmpty {
            tableView.beginUpdates()
            if isAnyInterfaceFieldAddedOrRemoved {
                handleSectionFieldsAddedOrRemoved(fields: TunnelDetailTableViewController.interfaceFields,
                                                  modelRowsInSection: &self.tableViewModelRowsBySection[0],
                                                  rowOffset: 0, changes: changes.interfaceChanges)
            }
            if isAnyPeerFieldAddedOrRemoved {
                for (peerIndex, peerChanges) in changes.peerChanges {
                    let sectionIndex = 1 + peerIndex
                    let rowOffset = self.tableViewModelRowsBySection[0 ..< sectionIndex].flatMap { $0.filter { $0.isVisible } }.count
                    handleSectionFieldsAddedOrRemoved(fields: TunnelDetailTableViewController.peerFields, modelRowsInSection: &self.tableViewModelRowsBySection[sectionIndex], rowOffset: rowOffset, changes: peerChanges)
                }
            }
            if !changes.peersRemovedIndices.isEmpty {
                for peerIndex in changes.peersRemovedIndices {
                    let sectionIndex = 1 + peerIndex
                    let rowOffset = self.tableViewModelRowsBySection[0 ..< sectionIndex].flatMap { $0.filter { $0.isVisible } }.count
                    let count = self.tableViewModelRowsBySection[sectionIndex].filter { $0.isVisible }.count
                    self.tableView.removeRows(at: IndexSet(integersIn: rowOffset ..< rowOffset + count), withAnimation: .effectFade)
                    self.tableViewModelRowsBySection.remove(at: sectionIndex)
                }
            }
            if !changes.peersInsertedIndices.isEmpty {
                for peerIndex in changes.peersInsertedIndices {
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
            }
            updateTableViewModelRows()
            tableView.endUpdates()
        }
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
            if field == .status {
                return statusCell()
            } else if field == .toggleStatus {
                return toggleStatusCell()
            } else {
                let cell: KeyValueRow = tableView.dequeueReusableCell()
                let localizedKeyString = modelRow.isTitleRow() ? modelRow.localizedSectionKeyString() : field.localizedUIString
                cell.key = tr(format: "macFieldKey (%@)", localizedKeyString)
                cell.value = tunnelViewModel.interfaceData[field]
                cell.isKeyInBold = modelRow.isTitleRow()
                return cell
            }
        case .peerFieldRow(let peerData, let field):
            let cell: KeyValueRow = tableView.dequeueReusableCell()
            let localizedKeyString = modelRow.isTitleRow() ? modelRow.localizedSectionKeyString() : field.localizedUIString
            cell.key = tr(format: "macFieldKey (%@)", localizedKeyString)
            if field == .persistentKeepAlive {
                cell.value = tr(format: "tunnelPeerPersistentKeepaliveValue (%@)", peerData[field])
            } else if field == .preSharedKey {
                cell.value = tr("tunnelPeerPresharedKeyEnabled")
            } else {
                cell.value = peerData[field]
            }
            cell.isKeyInBold = modelRow.isTitleRow()
            return cell
        case .spacerRow:
            return NSView()
        case .onDemandRow:
            let cell: KeyValueRow = tableView.dequeueReusableCell()
            cell.key = modelRow.localizedSectionKeyString()
            cell.value = onDemandViewModel.localizedInterfaceDescription
            cell.isKeyInBold = true
            return cell
        case .onDemandSSIDRow:
            let cell: KeyValueRow = tableView.dequeueReusableCell()
            cell.key = tr("macFieldOnDemandSSIDs")
            let value: String
            if onDemandViewModel.ssidOption == .anySSID {
                value = onDemandViewModel.ssidOption.localizedUIString
            } else {
                value = tr(format: "tunnelOnDemandSSIDOptionDescriptionMac (%1$@: %2$@)",
                           onDemandViewModel.ssidOption.localizedUIString,
                           onDemandViewModel.selectedSSIDs.joined(separator: ", "))
            }
            cell.value = value
            cell.isKeyInBold = false
            return cell
        }
    }

    func statusCell() -> NSView {
        let cell: KeyValueImageRow = tableView.dequeueReusableCell()
        cell.key = tr(format: "macFieldKey (%@)", tr("tunnelInterfaceStatus"))
        cell.value = TunnelDetailTableViewController.localizedStatusDescription(for: tunnel)
        cell.valueImage = TunnelDetailTableViewController.image(for: tunnel)
        let changeHandler: (TunnelContainer, Any) -> Void = { [weak cell] tunnel, _ in
            guard let cell = cell else { return }
            cell.value = TunnelDetailTableViewController.localizedStatusDescription(for: tunnel)
            cell.valueImage = TunnelDetailTableViewController.image(for: tunnel)
        }
        cell.statusObservationToken = tunnel.observe(\.status, changeHandler: changeHandler)
        cell.isOnDemandEnabledObservationToken = tunnel.observe(\.isActivateOnDemandEnabled, changeHandler: changeHandler)
        cell.hasOnDemandRulesObservationToken = tunnel.observe(\.hasOnDemandRules, changeHandler: changeHandler)
        return cell
    }

    func toggleStatusCell() -> NSView {
        let cell: ButtonRow = tableView.dequeueReusableCell()
        cell.buttonTitle = TunnelDetailTableViewController.localizedToggleStatusActionText(for: tunnel)
        cell.isButtonEnabled = (tunnel.hasOnDemandRules || tunnel.status == .active || tunnel.status == .inactive)
        cell.buttonToolTip = tr("macToolTipToggleStatus")
        cell.onButtonClicked = { [weak self] in
            self?.handleToggleActiveStatusAction()
        }
        let changeHandler: (TunnelContainer, Any) -> Void = { [weak cell] tunnel, _ in
            guard let cell = cell else { return }
            cell.buttonTitle = TunnelDetailTableViewController.localizedToggleStatusActionText(for: tunnel)
            cell.isButtonEnabled = (tunnel.hasOnDemandRules || tunnel.status == .active || tunnel.status == .inactive)
        }
        cell.statusObservationToken = tunnel.observe(\.status, changeHandler: changeHandler)
        cell.isOnDemandEnabledObservationToken = tunnel.observe(\.isActivateOnDemandEnabled, changeHandler: changeHandler)
        cell.hasOnDemandRulesObservationToken = tunnel.observe(\.hasOnDemandRules, changeHandler: changeHandler)
        return cell
    }

    private static func localizedStatusDescription(for tunnel: TunnelContainer) -> String {
        let status = tunnel.status
        let isOnDemandEngaged = tunnel.isActivateOnDemandEnabled

        var text: String
        switch status {
        case .inactive:
            text = tr("tunnelStatusInactive")
        case .activating:
            text = tr("tunnelStatusActivating")
        case .active:
            text = tr("tunnelStatusActive")
        case .deactivating:
            text = tr("tunnelStatusDeactivating")
        case .reasserting:
            text = tr("tunnelStatusReasserting")
        case .restarting:
            text = tr("tunnelStatusRestarting")
        case .waiting:
            text = tr("tunnelStatusWaiting")
        }

        if tunnel.hasOnDemandRules {
            text += isOnDemandEngaged ?
                tr("tunnelStatusAddendumOnDemandEnabled") : tr("tunnelStatusAddendumOnDemandDisabled")
        }

        return text
    }

    private static func image(for tunnel: TunnelContainer?) -> NSImage? {
        guard let tunnel = tunnel else { return nil }
        switch tunnel.status {
        case .active, .restarting, .reasserting:
            return NSImage(named: NSImage.statusAvailableName)
        case .activating, .waiting, .deactivating:
            return NSImage(named: NSImage.statusPartiallyAvailableName)
        case .inactive:
            if tunnel.isActivateOnDemandEnabled {
                return NSImage(named: NSImage.Name.statusOnDemandEnabled)
            } else {
                return NSImage(named: NSImage.statusNoneName)
            }
        }
    }

    private static func localizedToggleStatusActionText(for tunnel: TunnelContainer) -> String {
        if tunnel.hasOnDemandRules {
            let turnOn = !tunnel.isActivateOnDemandEnabled
            if turnOn {
                return tr("macToggleStatusButtonEnableOnDemand")
            } else {
                if tunnel.status == .active {
                    return tr("macToggleStatusButtonDisableOnDemandDeactivate")
                } else {
                    return tr("macToggleStatusButtonDisableOnDemand")
                }
            }
        } else {
            switch tunnel.status {
            case .waiting:
                return tr("macToggleStatusButtonWaiting")
            case .inactive:
                return tr("macToggleStatusButtonActivate")
            case .activating:
                return tr("macToggleStatusButtonActivating")
            case .active:
                return tr("macToggleStatusButtonDeactivate")
            case .deactivating:
                return tr("macToggleStatusButtonDeactivating")
            case .reasserting:
                return tr("macToggleStatusButtonReasserting")
            case .restarting:
                return tr("macToggleStatusButtonRestarting")
            }
        }
    }
}

extension TunnelDetailTableViewController: TunnelEditViewControllerDelegate {
    func tunnelSaved(tunnel: TunnelContainer) {
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration)
        onDemandViewModel = ActivateOnDemandViewModel(tunnel: tunnel)
        updateTableViewModelRowsBySection()
        updateTableViewModelRows()
        tableView.reloadData()
        self.tunnelEditVC = nil
    }

    func tunnelEditingCancelled() {
        self.tunnelEditVC = nil
    }
}
