// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

protocol TunnelEditTableViewControllerDelegate: class {
    func tunnelSaved(tunnel: TunnelContainer)
    func tunnelEditingCancelled()
}

// MARK: TunnelEditTableViewController

class TunnelEditTableViewController: UITableViewController {

    private enum Section {
        case interface
        case peer(_ peer: TunnelViewModel.PeerData)
        case addPeer
        case onDemand
    }

    weak var delegate: TunnelEditTableViewControllerDelegate?

    let interfaceFieldsBySection: [[TunnelViewModel.InterfaceField]] = [
        [.name],
        [.privateKey, .publicKey, .generateKeyPair],
        [.addresses, .listenPort, .mtu, .dns]
    ]

    let peerFields: [TunnelViewModel.PeerField] = [
        .publicKey, .preSharedKey, .endpoint,
        .allowedIPs, .excludePrivateIPs, .persistentKeepAlive,
        .deletePeer
    ]

    let activateOnDemandOptions: [ActivateOnDemandOption] = [
        .useOnDemandOverWiFiOrCellular,
        .useOnDemandOverWiFiOnly,
        .useOnDemandOverCellularOnly
    ]

    let tunnelsManager: TunnelsManager
    let tunnel: TunnelContainer?
    let tunnelViewModel: TunnelViewModel
    var activateOnDemandSetting: ActivateOnDemandSetting
    private var sections = [Section]()

    init(tunnelsManager: TunnelsManager, tunnel: TunnelContainer) {
        // Use this initializer to edit an existing tunnel.
        self.tunnelsManager = tunnelsManager
        self.tunnel = tunnel
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration())
        activateOnDemandSetting = tunnel.activateOnDemandSetting()
        super.init(style: .grouped)
        loadSections()
    }

    init(tunnelsManager: TunnelsManager, tunnelConfiguration: TunnelConfiguration?) {
        // Use this initializer to create a new tunnel.
        // If tunnelConfiguration is passed, data will be prepopulated from that configuration.
        self.tunnelsManager = tunnelsManager
        tunnel = nil
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnelConfiguration)
        activateOnDemandSetting = ActivateOnDemandSetting.defaultSetting
        super.init(style: .grouped)
        loadSections()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = tunnel == nil ? "New configuration" : "Edit configuration"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))

        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension

        tableView.register(TunnelEditKeyValueCell.self)
        tableView.register(TunnelEditEditableKeyValueCell.self)
        tableView.register(ButtonCell.self)
        tableView.register(SwitchCell.self)
        tableView.register(CheckmarkCell.self)
    }

    private func loadSections() {
        sections.removeAll()
        interfaceFieldsBySection.forEach { _ in sections.append(.interface) }
        tunnelViewModel.peersData.forEach { sections.append(.peer($0)) }
        sections.append(.addPeer)
        sections.append(.onDemand)
    }

    @objc func saveTapped() {
        tableView.endEditing(false)
        let tunnelSaveResult = tunnelViewModel.save()
        switch tunnelSaveResult {
        case .error(let errorMessage):
            let erroringConfiguration = (tunnelViewModel.interfaceData.validatedConfiguration == nil) ? "Interface" : "Peer"
            ErrorPresenter.showErrorAlert(title: "Invalid \(erroringConfiguration)", message: errorMessage, from: self)
            tableView.reloadData() // Highlight erroring fields
        case .saved(let tunnelConfiguration):
            if let tunnel = tunnel {
                // We're modifying an existing tunnel
                tunnelsManager.modify(tunnel: tunnel,
                                      tunnelConfiguration: tunnelConfiguration,
                                      activateOnDemandSetting: activateOnDemandSetting) { [weak self] error in
                    if let error = error {
                        ErrorPresenter.showErrorAlert(error: error, from: self)
                    } else {
                        self?.dismiss(animated: true, completion: nil)
                        self?.delegate?.tunnelSaved(tunnel: tunnel)
                    }
                }
            } else {
                // We're adding a new tunnel
                tunnelsManager.add(tunnelConfiguration: tunnelConfiguration,
                                   activateOnDemandSetting: activateOnDemandSetting) { [weak self] result in
                    if let error = result.error {
                        ErrorPresenter.showErrorAlert(error: error, from: self)
                    } else {
                        let tunnel: TunnelContainer = result.value!
                        self?.dismiss(animated: true, completion: nil)
                        self?.delegate?.tunnelSaved(tunnel: tunnel)
                    }
                }
            }
        }
    }

    @objc func cancelTapped() {
        dismiss(animated: true, completion: nil)
        delegate?.tunnelEditingCancelled()
    }
}

// MARK: UITableViewDataSource

extension TunnelEditTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .interface:
            return interfaceFieldsBySection[section].count
        case .peer(let peerData):
            let peerFieldsToShow = peerData.shouldAllowExcludePrivateIPsControl ? peerFields : peerFields.filter { $0 != .excludePrivateIPs }
            return peerFieldsToShow.count
        case .addPeer:
            return 1
        case .onDemand:
            if activateOnDemandSetting.isActivateOnDemandEnabled {
                return 4
            } else {
                return 1
            }
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .interface:
            return section == 0 ? "Interface" : nil
        case .peer:
            return "Peer"
        case .addPeer:
            return nil
        case .onDemand:
            return "On-Demand Activation"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .interface:
            return interfaceFieldCell(for: tableView, at: indexPath)
        case .peer(let peerData):
            return peerCell(for: tableView, at: indexPath, with: peerData)
        case .addPeer:
            return addPeerCell(for: tableView, at: indexPath)
        case .onDemand:
            return onDemandCell(for: tableView, at: indexPath)
        }
    }

    private func interfaceFieldCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let field = interfaceFieldsBySection[indexPath.section][indexPath.row]
        switch field {
        case .generateKeyPair:
            return generateKeyPairCell(for: tableView, at: indexPath, with: field)
        case .publicKey:
            return publicKeyCell(for: tableView, at: indexPath, with: field)
        default:
            return interfaceFieldKeyValueCell(for: tableView, at: indexPath, with: field)
        }
    }

    private func generateKeyPairCell(for tableView: UITableView, at indexPath: IndexPath, with field: TunnelViewModel.InterfaceField) -> UITableViewCell {
        let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)
        cell.buttonText = field.rawValue
        cell.onTapped = { [weak self] in
            guard let self = self else { return }

            self.tunnelViewModel.interfaceData[.privateKey] = Curve25519.generatePrivateKey().base64EncodedString()
            if let privateKeyRow = self.interfaceFieldsBySection[indexPath.section].firstIndex(of: .privateKey),
                let publicKeyRow = self.interfaceFieldsBySection[indexPath.section].firstIndex(of: .publicKey) {
                let privateKeyIndex = IndexPath(row: privateKeyRow, section: indexPath.section)
                let publicKeyIndex = IndexPath(row: publicKeyRow, section: indexPath.section)
                self.tableView.reloadRows(at: [privateKeyIndex, publicKeyIndex], with: .fade)
            }
        }
        return cell
    }

    private func publicKeyCell(for tableView: UITableView, at indexPath: IndexPath, with field: TunnelViewModel.InterfaceField) -> UITableViewCell {
        let cell: TunnelEditKeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.rawValue
        cell.value = tunnelViewModel.interfaceData[field]
        return cell
    }

    private func interfaceFieldKeyValueCell(for tableView: UITableView, at indexPath: IndexPath, with field: TunnelViewModel.InterfaceField) -> UITableViewCell {
        let cell: TunnelEditEditableKeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.rawValue

        switch field {
        case .name, .privateKey:
            cell.placeholderText = "Required"
            cell.keyboardType = .default
        case .addresses, .dns:
            cell.placeholderText = "Optional"
            cell.keyboardType = .numbersAndPunctuation
        case .listenPort, .mtu:
            cell.placeholderText = "Automatic"
            cell.keyboardType = .numberPad
        case .publicKey, .generateKeyPair:
            cell.keyboardType = .default
        }

        cell.isValueValid = (!tunnelViewModel.interfaceData.fieldsWithError.contains(field))
        // Bind values to view model
        cell.value = tunnelViewModel.interfaceData[field]
        if field == .dns { // While editing DNS, you might directly set exclude private IPs
            cell.onValueBeingEdited = { [weak self] value in
                self?.tunnelViewModel.interfaceData[field] = value
            }
        } else {
            cell.onValueChanged = { [weak self] value in
                self?.tunnelViewModel.interfaceData[field] = value
            }
        }
        // Compute public key live
        if field == .privateKey {
            cell.onValueBeingEdited = { [weak self] value in
                guard let self = self else { return }

                self.tunnelViewModel.interfaceData[.privateKey] = value
                if let row = self.interfaceFieldsBySection[indexPath.section].firstIndex(of: .publicKey) {
                    self.tableView.reloadRows(at: [IndexPath(row: row, section: indexPath.section)], with: .none)
                }
            }
        }
        return cell
    }

    private func peerCell(for tableView: UITableView, at indexPath: IndexPath, with peerData: TunnelViewModel.PeerData) -> UITableViewCell {
        let peerFieldsToShow = peerData.shouldAllowExcludePrivateIPsControl ? peerFields : peerFields.filter { $0 != .excludePrivateIPs }
        let field = peerFieldsToShow[indexPath.row]

        switch field {
        case .deletePeer:
            return deletePeerCell(for: tableView, at: indexPath, peerData: peerData, field: field)
        case .excludePrivateIPs:
            return excludePrivateIPsCell(for: tableView, at: indexPath, peerData: peerData, field: field)
        default:
            return peerFieldKeyValueCell(for: tableView, at: indexPath, peerData: peerData, field: field)
        }
    }

    private func deletePeerCell(for tableView: UITableView, at indexPath: IndexPath, peerData: TunnelViewModel.PeerData, field: TunnelViewModel.PeerField) -> UITableViewCell {
        let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)
        cell.buttonText = field.rawValue
        cell.hasDestructiveAction = true
        cell.onTapped = { [weak self, weak peerData] in
            guard let peerData = peerData else { return }
            guard let self = self else { return }
            self.showConfirmationAlert(message: "Delete this peer?", buttonTitle: "Delete", from: cell) { [weak self] in
                guard let self = self else { return }
                let removedSectionIndices = self.deletePeer(peer: peerData)
                let shouldShowExcludePrivateIPs = (self.tunnelViewModel.peersData.count == 1 && self.tunnelViewModel.peersData[0].shouldAllowExcludePrivateIPsControl)
                tableView.performBatchUpdates({
                    self.tableView.deleteSections(removedSectionIndices, with: .fade)
                    if shouldShowExcludePrivateIPs {
                        if let row = self.peerFields.firstIndex(of: .excludePrivateIPs) {
                            let rowIndexPath = IndexPath(row: row, section: self.interfaceFieldsBySection.count /* First peer section */)
                            self.tableView.insertRows(at: [rowIndexPath], with: .fade)
                        }

                    }
                })
            }
        }
        return cell
    }

    private func excludePrivateIPsCell(for tableView: UITableView, at indexPath: IndexPath, peerData: TunnelViewModel.PeerData, field: TunnelViewModel.PeerField) -> UITableViewCell {
        let cell: SwitchCell = tableView.dequeueReusableCell(for: indexPath)
        cell.message = field.rawValue
        cell.isEnabled = peerData.shouldAllowExcludePrivateIPsControl
        cell.isOn = peerData.excludePrivateIPsValue
        cell.onSwitchToggled = { [weak self] isOn in
            guard let self = self else { return }
            peerData.excludePrivateIPsValueChanged(isOn: isOn, dnsServers: self.tunnelViewModel.interfaceData[.dns])
            if let row = self.peerFields.firstIndex(of: .allowedIPs) {
                self.tableView.reloadRows(at: [IndexPath(row: row, section: indexPath.section)], with: .none)
            }
        }
        return cell
    }

    private func peerFieldKeyValueCell(for tableView: UITableView, at indexPath: IndexPath, peerData: TunnelViewModel.PeerData, field: TunnelViewModel.PeerField) -> UITableViewCell {
        let cell: TunnelEditEditableKeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.rawValue

        switch field {
        case .publicKey:
            cell.placeholderText = "Required"
            cell.keyboardType = .default
        case .preSharedKey, .endpoint:
            cell.placeholderText = "Optional"
            cell.keyboardType = .default
        case .allowedIPs:
            cell.placeholderText = "Optional"
            cell.keyboardType = .numbersAndPunctuation
        case .persistentKeepAlive:
            cell.placeholderText = "Off"
            cell.keyboardType = .numberPad
        case .excludePrivateIPs, .deletePeer:
            cell.keyboardType = .default
        }

        cell.isValueValid = !peerData.fieldsWithError.contains(field)
        cell.value = peerData[field]

        if field == .allowedIPs {
            cell.onValueBeingEdited = { [weak self, weak peerData] value in
                guard let self = self, let peerData = peerData else { return }

                let oldValue = peerData.shouldAllowExcludePrivateIPsControl
                peerData[.allowedIPs] = value
                if oldValue != peerData.shouldAllowExcludePrivateIPsControl {
                    if let row = self.peerFields.firstIndex(of: .excludePrivateIPs) {
                        if peerData.shouldAllowExcludePrivateIPsControl {
                            self.tableView.insertRows(at: [IndexPath(row: row, section: indexPath.section)], with: .fade)
                        } else {
                            self.tableView.deleteRows(at: [IndexPath(row: row, section: indexPath.section)], with: .fade)
                        }
                    }
                }
            }
        } else {
            cell.onValueChanged = { [weak peerData] value in
                peerData?[field] = value
            }
        }

        return cell
    }

    private func addPeerCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)
        cell.buttonText = "Add peer"
        cell.onTapped = { [weak self] in
            guard let self = self else { return }
            let shouldHideExcludePrivateIPs = (self.tunnelViewModel.peersData.count == 1 && self.tunnelViewModel.peersData[0].shouldAllowExcludePrivateIPsControl)
            let addedSectionIndices = self.appendEmptyPeer()
            tableView.performBatchUpdates({
                tableView.insertSections(addedSectionIndices, with: .fade)
                if shouldHideExcludePrivateIPs {
                    if let row = self.peerFields.firstIndex(of: .excludePrivateIPs) {
                        let rowIndexPath = IndexPath(row: row, section: self.interfaceFieldsBySection.count /* First peer section */)
                        self.tableView.deleteRows(at: [rowIndexPath], with: .fade)
                    }
                }
            }, completion: nil)
        }
        return cell
    }

    private func onDemandCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell: SwitchCell = tableView.dequeueReusableCell(for: indexPath)
            cell.message = "Activate on demand"
            cell.isOn = activateOnDemandSetting.isActivateOnDemandEnabled
            cell.onSwitchToggled = { [weak self] isOn in
                guard let self = self else { return }
                guard isOn != self.activateOnDemandSetting.isActivateOnDemandEnabled else { return }

                let indexPaths = (1 ..< 4).map { IndexPath(row: $0, section: indexPath.section) }
                if isOn {
                    self.activateOnDemandSetting.isActivateOnDemandEnabled = true
                    if self.activateOnDemandSetting.activateOnDemandOption == .none {
                        self.activateOnDemandSetting.activateOnDemandOption = TunnelViewModel.defaultActivateOnDemandOption()
                    }
                    self.loadSections()
                    self.tableView.insertRows(at: indexPaths, with: .fade)
                } else {
                    self.activateOnDemandSetting.isActivateOnDemandEnabled = false
                    self.loadSections()
                    self.tableView.deleteRows(at: indexPaths, with: .fade)
                }
            }
            return cell
        } else {
            let cell: CheckmarkCell = tableView.dequeueReusableCell(for: indexPath)
            let rowOption = activateOnDemandOptions[indexPath.row - 1]
            let selectedOption = activateOnDemandSetting.activateOnDemandOption
            assert(selectedOption != .none)
            cell.message = TunnelViewModel.activateOnDemandOptionText(for: rowOption)
            cell.isChecked = (selectedOption == rowOption)
            return cell
        }
    }

    func appendEmptyPeer() -> IndexSet {
        tunnelViewModel.appendEmptyPeer()
        loadSections()
        let addedPeerIndex = tunnelViewModel.peersData.count - 1
        return IndexSet(integer: interfaceFieldsBySection.count + addedPeerIndex)
    }

    func deletePeer(peer: TunnelViewModel.PeerData) -> IndexSet {
        tunnelViewModel.deletePeer(peer: peer)
        loadSections()
        return IndexSet(integer: interfaceFieldsBySection.count + peer.index)
    }

    func showConfirmationAlert(message: String, buttonTitle: String, from sourceView: UIView, onConfirmed: @escaping (() -> Void)) {
        let destroyAction = UIAlertAction(title: buttonTitle, style: .destructive) { _ in
            onConfirmed()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let alert = UIAlertController(title: "", message: message, preferredStyle: .actionSheet)
        alert.addAction(destroyAction)
        alert.addAction(cancelAction)

        alert.popoverPresentationController?.sourceView = sourceView
        alert.popoverPresentationController?.sourceRect = sourceView.bounds

        present(alert, animated: true, completion: nil)
    }
}

// MARK: UITableViewDelegate

extension TunnelEditTableViewController {
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if case .onDemand = sections[indexPath.section], indexPath.row > 0 {
            return indexPath
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .onDemand:
            let option = activateOnDemandOptions[indexPath.row - 1]
            assert(option != .none)
            activateOnDemandSetting.activateOnDemandOption = option

            let indexPaths = (1 ..< 4).map { IndexPath(row: $0, section: indexPath.section) }
            UIView.performWithoutAnimation {
                tableView.reloadRows(at: indexPaths, with: .none)
            }
        default:
            assertionFailure()
        }
    }
}
