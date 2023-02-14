// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class TunnelDetailTableViewController: UITableViewController {

    private enum Section {
        case status
        case interface
        case peer(index: Int, peer: TunnelViewModel.PeerData)
        case onDemand
        case delete
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

    static let onDemandFields: [ActivateOnDemandViewModel.OnDemandField] = [
        .onDemand, .ssid
    ]

    let tunnelsManager: TunnelsManager
    let tunnel: TunnelContainer
    var tunnelViewModel: TunnelViewModel
    var onDemandViewModel: ActivateOnDemandViewModel

    private var sections = [Section]()
    private var interfaceFieldIsVisible = [Bool]()
    private var peerFieldIsVisible = [[Bool]]()

    private var statusObservationToken: AnyObject?
    private var onDemandObservationToken: AnyObject?
    private var reloadRuntimeConfigurationTimer: Timer?

    init(tunnelsManager: TunnelsManager, tunnel: TunnelContainer) {
        self.tunnelsManager = tunnelsManager
        self.tunnel = tunnel
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration)
        onDemandViewModel = ActivateOnDemandViewModel(tunnel: tunnel)
        super.init(style: .grouped)
        loadSections()
        loadVisibleFields()
        statusObservationToken = tunnel.observe(\.status) { [weak self] _, _ in
            guard let self = self else { return }
            if tunnel.status == .active {
                self.startUpdatingRuntimeConfiguration()
            } else if tunnel.status == .inactive {
                self.reloadRuntimeConfiguration()
                self.stopUpdatingRuntimeConfiguration()
            }
        }
        onDemandObservationToken = tunnel.observe(\.isActivateOnDemandEnabled) { [weak self] tunnel, _ in
            // Handle On-Demand getting turned on/off outside of the app
            self?.onDemandViewModel = ActivateOnDemandViewModel(tunnel: tunnel)
            self?.updateActivateOnDemandFields()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = tunnelViewModel.interfaceData[.name]
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editTapped))

        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(SwitchCell.self)
        tableView.register(KeyValueCell.self)
        tableView.register(ButtonCell.self)
        tableView.register(ChevronCell.self)

        restorationIdentifier = "TunnelDetailVC:\(tunnel.name)"
    }

    private func loadSections() {
        sections.removeAll()
        sections.append(.status)
        sections.append(.interface)
        for (index, peer) in tunnelViewModel.peersData.enumerated() {
            sections.append(.peer(index: index, peer: peer))
        }
        sections.append(.onDemand)
        sections.append(.delete)
    }

    private func loadVisibleFields() {
        let visibleInterfaceFields = tunnelViewModel.interfaceData.filterFieldsWithValueOrControl(interfaceFields: TunnelDetailTableViewController.interfaceFields)
        interfaceFieldIsVisible = TunnelDetailTableViewController.interfaceFields.map { visibleInterfaceFields.contains($0) }
        peerFieldIsVisible = tunnelViewModel.peersData.map { peer in
            let visiblePeerFields = peer.filterFieldsWithValueOrControl(peerFields: TunnelDetailTableViewController.peerFields)
            return TunnelDetailTableViewController.peerFields.map { visiblePeerFields.contains($0) }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        if tunnel.status == .active {
            self.startUpdatingRuntimeConfiguration()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        stopUpdatingRuntimeConfiguration()
    }

    @objc func editTapped() {
        PrivateDataConfirmation.confirmAccess(to: tr("iosViewPrivateData")) { [weak self] in
            guard let self = self else { return }
            let editVC = TunnelEditTableViewController(tunnelsManager: self.tunnelsManager, tunnel: self.tunnel)
            editVC.delegate = self
            let editNC = UINavigationController(rootViewController: editVC)
            editNC.modalPresentationStyle = .fullScreen
            self.present(editNC, animated: true)
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
        reloadRuntimeConfigurationTimer?.invalidate()
        reloadRuntimeConfigurationTimer = nil
    }

    func applyTunnelConfiguration(tunnelConfiguration: TunnelConfiguration) {
        // Incorporates changes from tunnelConfiguation. Ignores any changes in peer ordering.
        guard let tableView = self.tableView else { return }
        let sections = self.sections
        let interfaceSectionIndex = sections.firstIndex {
            if case .interface = $0 {
                return true
            } else {
                return false
            }
        }!
        let firstPeerSectionIndex = interfaceSectionIndex + 1
        let interfaceFieldIsVisible = self.interfaceFieldIsVisible
        let peerFieldIsVisible = self.peerFieldIsVisible

        func handleSectionFieldsModified<T>(fields: [T], fieldIsVisible: [Bool], section: Int, changes: [T: TunnelViewModel.Changes.FieldChange]) {
            for (index, field) in fields.enumerated() {
                guard let change = changes[field] else { continue }
                if case .modified(let newValue) = change {
                    let row = fieldIsVisible[0 ..< index].filter { $0 }.count
                    let indexPath = IndexPath(row: row, section: section)
                    if let cell = tableView.cellForRow(at: indexPath) as? KeyValueCell {
                        cell.value = newValue
                    }
                }
            }
        }

        func handleSectionRowsInsertedOrRemoved<T>(fields: [T], fieldIsVisible fieldIsVisibleInput: [Bool], section: Int, changes: [T: TunnelViewModel.Changes.FieldChange]) {
            var fieldIsVisible = fieldIsVisibleInput

            var removedIndexPaths = [IndexPath]()
            for (index, field) in fields.enumerated().reversed() where changes[field] == .removed {
                let row = fieldIsVisible[0 ..< index].filter { $0 }.count
                removedIndexPaths.append(IndexPath(row: row, section: section))
                fieldIsVisible[index] = false
            }
            if !removedIndexPaths.isEmpty {
                tableView.deleteRows(at: removedIndexPaths, with: .automatic)
            }

            var addedIndexPaths = [IndexPath]()
            for (index, field) in fields.enumerated() where changes[field] == .added {
                let row = fieldIsVisible[0 ..< index].filter { $0 }.count
                addedIndexPaths.append(IndexPath(row: row, section: section))
                fieldIsVisible[index] = true
            }
            if !addedIndexPaths.isEmpty {
                tableView.insertRows(at: addedIndexPaths, with: .automatic)
            }
        }

        let changes = self.tunnelViewModel.applyConfiguration(other: tunnelConfiguration)

        if !changes.interfaceChanges.isEmpty {
            handleSectionFieldsModified(fields: TunnelDetailTableViewController.interfaceFields, fieldIsVisible: interfaceFieldIsVisible,
                                        section: interfaceSectionIndex, changes: changes.interfaceChanges)
        }
        for (peerIndex, peerChanges) in changes.peerChanges {
            handleSectionFieldsModified(fields: TunnelDetailTableViewController.peerFields, fieldIsVisible: peerFieldIsVisible[peerIndex], section: firstPeerSectionIndex + peerIndex, changes: peerChanges)
        }

        let isAnyInterfaceFieldAddedOrRemoved = changes.interfaceChanges.contains { $0.value == .added || $0.value == .removed }
        let isAnyPeerFieldAddedOrRemoved = changes.peerChanges.contains { $0.changes.contains { $0.value == .added || $0.value == .removed } }
        let peersRemovedSectionIndices = changes.peersRemovedIndices.map { firstPeerSectionIndex + $0 }
        let peersInsertedSectionIndices = changes.peersInsertedIndices.map { firstPeerSectionIndex + $0 }

        if isAnyInterfaceFieldAddedOrRemoved || isAnyPeerFieldAddedOrRemoved || !peersRemovedSectionIndices.isEmpty || !peersInsertedSectionIndices.isEmpty {
            tableView.beginUpdates()
            if isAnyInterfaceFieldAddedOrRemoved {
                handleSectionRowsInsertedOrRemoved(fields: TunnelDetailTableViewController.interfaceFields, fieldIsVisible: interfaceFieldIsVisible, section: interfaceSectionIndex, changes: changes.interfaceChanges)
            }
            if isAnyPeerFieldAddedOrRemoved {
                for (peerIndex, peerChanges) in changes.peerChanges {
                    handleSectionRowsInsertedOrRemoved(fields: TunnelDetailTableViewController.peerFields, fieldIsVisible: peerFieldIsVisible[peerIndex], section: firstPeerSectionIndex + peerIndex, changes: peerChanges)
                }
            }
            if !peersRemovedSectionIndices.isEmpty {
                tableView.deleteSections(IndexSet(peersRemovedSectionIndices), with: .automatic)
            }
            if !peersInsertedSectionIndices.isEmpty {
                tableView.insertSections(IndexSet(peersInsertedSectionIndices), with: .automatic)
            }
            self.loadSections()
            self.loadVisibleFields()
            tableView.endUpdates()
        } else {
            self.loadSections()
            self.loadVisibleFields()
        }
    }

    private func reloadRuntimeConfiguration() {
        tunnel.getRuntimeTunnelConfiguration { [weak self] tunnelConfiguration in
            guard let tunnelConfiguration = tunnelConfiguration else { return }
            guard let self = self else { return }
            self.applyTunnelConfiguration(tunnelConfiguration: tunnelConfiguration)
        }
    }

    private func updateActivateOnDemandFields() {
        guard let onDemandSection = sections.firstIndex(where: { if case .onDemand = $0 { return true } else { return false } }) else { return }
        let numberOfTableViewOnDemandRows = tableView.numberOfRows(inSection: onDemandSection)
        let ssidRowIndexPath = IndexPath(row: 1, section: onDemandSection)
        switch (numberOfTableViewOnDemandRows, onDemandViewModel.isWiFiInterfaceEnabled) {
        case (1, true):
            tableView.insertRows(at: [ssidRowIndexPath], with: .automatic)
        case (2, false):
            tableView.deleteRows(at: [ssidRowIndexPath], with: .automatic)
        default:
            break
        }
        tableView.reloadSections(IndexSet(integer: onDemandSection), with: .automatic)
    }
}

extension TunnelDetailTableViewController: TunnelEditTableViewControllerDelegate {
    func tunnelSaved(tunnel: TunnelContainer) {
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration)
        onDemandViewModel = ActivateOnDemandViewModel(tunnel: tunnel)
        loadSections()
        loadVisibleFields()
        title = tunnel.name
        restorationIdentifier = "TunnelDetailVC:\(tunnel.name)"
        tableView.reloadData()
    }
    func tunnelEditingCancelled() {
        // Nothing to do
    }
}

extension TunnelDetailTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .status:
            return 1
        case .interface:
            return interfaceFieldIsVisible.filter { $0 }.count
        case .peer(let peerIndex, _):
            return peerFieldIsVisible[peerIndex].filter { $0 }.count
        case .onDemand:
            return onDemandViewModel.isWiFiInterfaceEnabled ? 2 : 1
        case .delete:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .status:
            return tr("tunnelSectionTitleStatus")
        case .interface:
            return tr("tunnelSectionTitleInterface")
        case .peer:
            return tr("tunnelSectionTitlePeer")
        case .onDemand:
            return tr("tunnelSectionTitleOnDemand")
        case .delete:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .status:
            return statusCell(for: tableView, at: indexPath)
        case .interface:
            return interfaceCell(for: tableView, at: indexPath)
        case .peer(let index, let peer):
            return peerCell(for: tableView, at: indexPath, with: peer, peerIndex: index)
        case .onDemand:
            return onDemandCell(for: tableView, at: indexPath)
        case .delete:
            return deleteConfigurationCell(for: tableView, at: indexPath)
        }
    }

    private func statusCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: SwitchCell = tableView.dequeueReusableCell(for: indexPath)

        func update(cell: SwitchCell?, with tunnel: TunnelContainer) {
            guard let cell = cell else { return }

            let status = tunnel.status
            let isOnDemandEngaged = tunnel.isActivateOnDemandEnabled

            let isSwitchOn = (status == .activating || status == .active || isOnDemandEngaged)
            cell.switchView.setOn(isSwitchOn, animated: true)

            if isOnDemandEngaged && !(status == .activating || status == .active) {
                cell.switchView.onTintColor = UIColor.systemYellow
            } else {
                cell.switchView.onTintColor = UIColor.systemGreen
            }

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
                text += isOnDemandEngaged ? tr("tunnelStatusAddendumOnDemand") : ""
                cell.switchView.isUserInteractionEnabled = true
                cell.isEnabled = true
            } else {
                cell.switchView.isUserInteractionEnabled = (status == .inactive || status == .active)
                cell.isEnabled = (status == .inactive || status == .active)
            }

            if tunnel.hasOnDemandRules && !isOnDemandEngaged && status == .inactive {
                text = tr("tunnelStatusOnDemandDisabled")
            }

            cell.textLabel?.text = text
        }

        update(cell: cell, with: tunnel)
        cell.statusObservationToken = tunnel.observe(\.status) { [weak cell] tunnel, _ in
            update(cell: cell, with: tunnel)
        }
        cell.isOnDemandEnabledObservationToken = tunnel.observe(\.isActivateOnDemandEnabled) { [weak cell] tunnel, _ in
            update(cell: cell, with: tunnel)
        }
        cell.hasOnDemandRulesObservationToken = tunnel.observe(\.hasOnDemandRules) { [weak cell] tunnel, _ in
            update(cell: cell, with: tunnel)
        }

        cell.onSwitchToggled = { [weak self] isOn in
            guard let self = self else { return }

            if self.tunnel.hasOnDemandRules {
                self.tunnelsManager.setOnDemandEnabled(isOn, on: self.tunnel) { error in
                    if error == nil && !isOn {
                        self.tunnelsManager.startDeactivation(of: self.tunnel)
                    }
                }
            } else {
                if isOn {
                    self.tunnelsManager.startActivation(of: self.tunnel)
                } else {
                    self.tunnelsManager.startDeactivation(of: self.tunnel)
                }
            }
        }
        return cell
    }

    private func interfaceCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let visibleInterfaceFields = TunnelDetailTableViewController.interfaceFields.enumerated().filter { interfaceFieldIsVisible[$0.offset] }.map { $0.element }
        let field = visibleInterfaceFields[indexPath.row]
        let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.localizedUIString
        cell.value = tunnelViewModel.interfaceData[field]
        return cell
    }

    private func peerCell(for tableView: UITableView, at indexPath: IndexPath, with peerData: TunnelViewModel.PeerData, peerIndex: Int) -> UITableViewCell {
        let visiblePeerFields = TunnelDetailTableViewController.peerFields.enumerated().filter { peerFieldIsVisible[peerIndex][$0.offset] }.map { $0.element }
        let field = visiblePeerFields[indexPath.row]
        let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.localizedUIString
        if field == .persistentKeepAlive {
            cell.value = tr(format: "tunnelPeerPersistentKeepaliveValue (%@)", peerData[field])
        } else if field == .preSharedKey {
            cell.value = tr("tunnelPeerPresharedKeyEnabled")
        } else {
            cell.value = peerData[field]
        }
        return cell
    }

    private func onDemandCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let field = TunnelDetailTableViewController.onDemandFields[indexPath.row]
        if field == .onDemand {
            let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
            cell.key = field.localizedUIString
            cell.value = onDemandViewModel.localizedInterfaceDescription
            cell.copyableGesture = false
            return cell
        } else {
            assert(field == .ssid)
            if onDemandViewModel.ssidOption == .anySSID {
                let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
                cell.key = field.localizedUIString
                cell.value = onDemandViewModel.ssidOption.localizedUIString
                cell.copyableGesture = false
                return cell
            } else {
                let cell: ChevronCell = tableView.dequeueReusableCell(for: indexPath)
                cell.message = field.localizedUIString
                cell.detailMessage = onDemandViewModel.localizedSSIDDescription
                return cell
            }
        }
    }

    private func deleteConfigurationCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)
        cell.buttonText = tr("deleteTunnelButtonTitle")
        cell.hasDestructiveAction = true
        cell.onTapped = { [weak self] in
            guard let self = self else { return }
            ConfirmationAlertPresenter.showConfirmationAlert(message: tr("deleteTunnelConfirmationAlertMessage"),
                                       buttonTitle: tr("deleteTunnelConfirmationAlertButtonTitle"),
                                       from: cell, presentingVC: self) { [weak self] in
                guard let self = self else { return }
                self.tunnelsManager.remove(tunnel: self.tunnel) { error in
                    if error != nil {
                        print("Error removing tunnel: \(String(describing: error))")
                        return
                    }
                }
            }
        }
        return cell
    }

}

extension TunnelDetailTableViewController {
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if case .onDemand = sections[indexPath.section],
            case .ssid = TunnelDetailTableViewController.onDemandFields[indexPath.row] {
            return indexPath
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if case .onDemand = sections[indexPath.section],
            case .ssid = TunnelDetailTableViewController.onDemandFields[indexPath.row] {
            let ssidDetailVC = SSIDOptionDetailTableViewController(title: onDemandViewModel.ssidOption.localizedUIString, ssids: onDemandViewModel.selectedSSIDs)
            navigationController?.pushViewController(ssidDetailVC, animated: true)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
