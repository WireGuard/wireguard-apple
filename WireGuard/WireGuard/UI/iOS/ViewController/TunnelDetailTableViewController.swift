// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

class TunnelDetailTableViewController: UITableViewController {

    private enum Section {
        case status
        case interface
        case peer(_ peer: TunnelViewModel.PeerData)
        case onDemand
        case delete
    }

    let interfaceFields: [TunnelViewModel.InterfaceField] = [
        .name, .publicKey, .addresses,
        .listenPort, .mtu, .dns
    ]

    let peerFields: [TunnelViewModel.PeerField] = [
        .publicKey, .preSharedKey, .endpoint,
        .allowedIPs, .persistentKeepAlive
    ]

    let tunnelsManager: TunnelsManager
    let tunnel: TunnelContainer
    var tunnelViewModel: TunnelViewModel
    private var sections = [Section]()
    private var onDemandStatusObservationToken: AnyObject?
    private var statusObservationToken: AnyObject?

    init(tunnelsManager: TunnelsManager, tunnel: TunnelContainer) {
        self.tunnelsManager = tunnelsManager
        self.tunnel = tunnel
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration)
        super.init(style: .grouped)
        loadSections()
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
        tunnelViewModel.peersData.forEach { sections.append(.peer($0)) }
        sections.append(.onDemand)
        sections.append(.delete)
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
}

// MARK: TunnelEditTableViewControllerDelegate

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

// MARK: UITableViewDataSource

extension TunnelDetailTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .status:
            return 1
        case .interface:
             return tunnelViewModel.interfaceData.filterFieldsWithValueOrControl(interfaceFields: interfaceFields).count
        case .peer(let peerData):
            return peerData.filterFieldsWithValueOrControl(peerFields: peerFields).count
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
        case .peer(let peer):
            return peerCell(for: tableView, at: indexPath, with: peer)
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
        statusObservationToken = tunnel.observe(\.status) { [weak cell] tunnel, _ in
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
        let field = tunnelViewModel.interfaceData.filterFieldsWithValueOrControl(interfaceFields: interfaceFields)[indexPath.row]
        let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.localizedUIString
        cell.value = tunnelViewModel.interfaceData[field]
        return cell
    }

    private func peerCell(for tableView: UITableView, at indexPath: IndexPath, with peerData: TunnelViewModel.PeerData) -> UITableViewCell {
        let field = peerData.filterFieldsWithValueOrControl(peerFields: peerFields)[indexPath.row]
        let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.localizedUIString
        cell.value = peerData[field]
        return cell
    }

    private func onDemandCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = tr("tunnelOnDemandKey")
        cell.value = TunnelViewModel.activateOnDemandDetailText(for: tunnel.activateOnDemandSetting)
        onDemandStatusObservationToken = tunnel.observe(\.isActivateOnDemandEnabled) { [weak cell] tunnel, _ in
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
                if self.splitViewController?.isCollapsed != false {
                    self.navigationController?.navigationController?.popToRootViewController(animated: true)
                } else {
                    let detailVC = UIViewController()
                    detailVC.view.backgroundColor = .white
                    let detailNC = UINavigationController(rootViewController: detailVC)
                    self.showDetailViewController(detailNC, sender: self)
                }
            }
        }
        return cell
    }

}
