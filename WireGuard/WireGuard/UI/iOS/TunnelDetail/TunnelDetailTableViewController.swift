// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

// MARK: TunnelDetailTableViewController

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

    init(tunnelsManager: TunnelsManager, tunnel: TunnelContainer) {
        self.tunnelsManager = tunnelsManager
        self.tunnel = tunnel
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration())
        super.init(style: .grouped)
        loadSections()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = tunnelViewModel.interfaceData[.name]
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editTapped))

        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.allowsSelection = false
        self.tableView.register(TunnelDetailStatusCell.self)
        self.tableView.register(TunnelDetailKeyValueCell.self)
        self.tableView.register(TunnelDetailButtonCell.self)
        self.tableView.register(TunnelDetailActivateOnDemandCell.self)

        // State restoration
        self.restorationIdentifier = "TunnelDetailVC:\(tunnel.name)"
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

    func showConfirmationAlert(message: String, buttonTitle: String, from sourceView: UIView,
                               onConfirmed: @escaping (() -> Void)) {
        let destroyAction = UIAlertAction(title: buttonTitle, style: .destructive) { _ in
            onConfirmed()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let alert = UIAlertController(title: "", message: message, preferredStyle: .actionSheet)
        alert.addAction(destroyAction)
        alert.addAction(cancelAction)

        // popoverPresentationController will be nil on iPhone and non-nil on iPad
        alert.popoverPresentationController?.sourceView = sourceView
        alert.popoverPresentationController?.sourceRect = sourceView.bounds

        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: TunnelEditTableViewControllerDelegate

extension TunnelDetailTableViewController: TunnelEditTableViewControllerDelegate {
    func tunnelSaved(tunnel: TunnelContainer) {
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration())
        loadSections()
        self.title = tunnel.name
        self.tableView.reloadData()
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
            return "Status"
        case .interface:
            return "Interface"
        case .peer:
            return "Peer"
        case .onDemand:
            return "On-Demand Activation"
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
        let cell: TunnelDetailStatusCell = tableView.dequeueReusableCell(for: indexPath)
        cell.tunnel = self.tunnel
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
        let cell: TunnelDetailKeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.rawValue
        cell.value = tunnelViewModel.interfaceData[field]
        return cell
    }

    private func peerCell(for tableView: UITableView, at indexPath: IndexPath, with peerData: TunnelViewModel.PeerData) -> UITableViewCell {
        let field = peerData.filterFieldsWithValueOrControl(peerFields: peerFields)[indexPath.row]
        let cell: TunnelDetailKeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.rawValue
        cell.value = peerData[field]
        return cell
    }

    private func onDemandCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: TunnelDetailActivateOnDemandCell = tableView.dequeueReusableCell(for: indexPath)
        cell.tunnel = self.tunnel
        return cell
    }

    private func deleteConfigurationCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: TunnelDetailButtonCell = tableView.dequeueReusableCell(for: indexPath)
        cell.buttonText = "Delete tunnel"
        cell.hasDestructiveAction = true
        cell.onTapped = { [weak self] in
            guard let self = self else { return }
            self.showConfirmationAlert(message: "Delete this tunnel?", buttonTitle: "Delete", from: cell) { [weak self] in
                guard let tunnelsManager = self?.tunnelsManager, let tunnel = self?.tunnel else { return }
                tunnelsManager.remove(tunnel: tunnel) { error in
                    if error != nil {
                        print("Error removing tunnel: \(String(describing: error))")
                        return
                    }
                }
                self?.navigationController?.navigationController?.popToRootViewController(animated: true)
            }
        }
        return cell
    }

}
