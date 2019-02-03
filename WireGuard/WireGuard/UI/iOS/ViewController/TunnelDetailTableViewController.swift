// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

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

    let tunnelsManager: TunnelsManager
    let tunnel: TunnelContainer
    var tunnelViewModel: TunnelViewModel

    private var sections = [Section]()
    private var interfaceFieldIsVisible = [Bool]()
    private var peerFieldIsVisible = [[Bool]]()

    private var statusObservationToken: AnyObject?
    private var reloadRuntimeConfigurationTimer: Timer?

    init(tunnelsManager: TunnelsManager, tunnel: TunnelContainer) {
        self.tunnelsManager = tunnelsManager
        self.tunnel = tunnel
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration)
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
        tableView.allowsSelection = false
        tableView.register(SwitchCell.self)
        tableView.register(KeyValueCell.self)
        tableView.register(ButtonCell.self)

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
        let editVC = TunnelEditTableViewController(tunnelsManager: tunnelsManager, tunnel: tunnel)
        editVC.delegate = self
        let editNC = UINavigationController(rootViewController: editVC)
        editNC.modalPresentationStyle = .formSheet
        present(editNC, animated: true)
    }

    func showConfirmationAlert(message: String, buttonTitle: String, from sourceView: UIView, onConfirmed: @escaping (() -> Void)) {
        let destroyAction = UIAlertAction(title: buttonTitle, style: .destructive) { _ in
            onConfirmed()
        }
        let cancelAction = UIAlertAction(title: tr("actionCancel"), style: .cancel)
        let alert = UIAlertController(title: "", message: message, preferredStyle: .actionSheet)
        alert.addAction(destroyAction)
        alert.addAction(cancelAction)

        alert.popoverPresentationController?.sourceView = sourceView
        alert.popoverPresentationController?.sourceRect = sourceView.bounds

        present(alert, animated: true, completion: nil)
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
        let interfaceSectionIndex = sections.firstIndex(where: { if case .interface = $0 { return true } else { return false }})!
        let firstPeerSectionIndex = interfaceSectionIndex + 1
        var interfaceFieldIsVisible = self.interfaceFieldIsVisible
        var peerFieldIsVisible = self.peerFieldIsVisible

        func sectionChanged<T>(fields: [T], fieldIsVisible fieldIsVisibleInput: [Bool], tableView: UITableView, section: Int, changes: [T: TunnelViewModel.ChangeHandlers.FieldChange]) {
            var fieldIsVisible = fieldIsVisibleInput
            var modifiedIndexPaths = [IndexPath]()
            for (index, field) in fields.enumerated() where changes[field] == .modified {
                let row = fieldIsVisible[0 ..< index].filter { $0 }.count
                modifiedIndexPaths.append(IndexPath(row: row, section: section))
            }
            if !modifiedIndexPaths.isEmpty {
                tableView.reloadRows(at: modifiedIndexPaths, with: .automatic)
            }

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

        let changeHandlers = TunnelViewModel.ChangeHandlers(
            interfaceChanged: { changes in
                sectionChanged(fields: TunnelDetailTableViewController.interfaceFields, fieldIsVisible: interfaceFieldIsVisible,
                               tableView: tableView, section: interfaceSectionIndex, changes: changes)
            },
            peerChangedAt: { peerIndex, changes in
                sectionChanged(fields: TunnelDetailTableViewController.peerFields, fieldIsVisible: peerFieldIsVisible[peerIndex],
                               tableView: tableView, section: firstPeerSectionIndex + peerIndex, changes: changes)
            },
            peersRemovedAt: { peerIndices in
                let sectionIndices = peerIndices.map { firstPeerSectionIndex + $0 }
                tableView.deleteSections(IndexSet(sectionIndices), with: .automatic)
            },
            peersInsertedAt: { peerIndices in
                let sectionIndices = peerIndices.map { firstPeerSectionIndex + $0 }
                tableView.insertSections(IndexSet(sectionIndices), with: .automatic)
            }
        )

        tableView.beginUpdates()
        self.tunnelViewModel.applyConfiguration(other: tunnelConfiguration, changeHandlers: changeHandlers)
        self.loadSections()
        self.loadVisibleFields()
        tableView.endUpdates()
    }

    private func reloadRuntimeConfiguration() {
        tunnel.getRuntimeTunnelConfiguration { [weak self] tunnelConfiguration in
            guard let tunnelConfiguration = tunnelConfiguration else { return }
            guard let self = self else { return }
            self.applyTunnelConfiguration(tunnelConfiguration: tunnelConfiguration)
        }
    }
}

extension TunnelDetailTableViewController: TunnelEditTableViewControllerDelegate {
    func tunnelSaved(tunnel: TunnelContainer) {
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration)
        loadSections()
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
            return 1
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

        let statusUpdate: (SwitchCell, TunnelStatus) -> Void = { cell, status in
            let text: String
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
            cell.textLabel?.text = text
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak cell] in
                cell?.switchView.isOn = !(status == .deactivating || status == .inactive)
                cell?.switchView.isUserInteractionEnabled = (status == .inactive || status == .active)
            }
            cell.isEnabled = status == .active || status == .inactive
        }

        statusUpdate(cell, tunnel.status)
        cell.observationToken = tunnel.observe(\.status) { [weak cell] tunnel, _ in
            guard let cell = cell else { return }
            statusUpdate(cell, tunnel.status)
        }

        cell.onSwitchToggled = { [weak self] isOn in
            guard let self = self else { return }
            if isOn {
                self.tunnelsManager.startActivation(of: self.tunnel)
            } else {
                self.tunnelsManager.startDeactivation(of: self.tunnel)
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
        } else {
            cell.value = peerData[field]
        }
        return cell
    }

    private func onDemandCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = tr("tunnelOnDemandKey")
        cell.value = TunnelViewModel.activateOnDemandDetailText(for: tunnel.activateOnDemandSetting)
        cell.observationToken = tunnel.observe(\.isActivateOnDemandEnabled) { [weak cell] tunnel, _ in
            cell?.value = TunnelViewModel.activateOnDemandDetailText(for: tunnel.activateOnDemandSetting)
        }
        return cell
    }

    private func deleteConfigurationCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)
        cell.buttonText = tr("deleteTunnelButtonTitle")
        cell.hasDestructiveAction = true
        cell.onTapped = { [weak self] in
            guard let self = self else { return }
            self.showConfirmationAlert(message: tr("deleteTunnelConfirmationAlertMessage"), buttonTitle: tr("deleteTunnelConfirmationAlertButtonTitle"), from: cell) { [weak self] in
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
