// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

protocol TunnelEditTableViewControllerDelegate: class {
    func tunnelSaved(tunnel: TunnelContainer)
    func tunnelEditingCancelled()
}

// MARK: TunnelEditTableViewController

class TunnelEditTableViewController: UITableViewController {

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
        .useOnDemandOverWifiOrCellular,
        .useOnDemandOverWifiOnly,
        .useOnDemandOverCellularOnly
    ]

    let tunnelsManager: TunnelsManager
    let tunnel: TunnelContainer?
    let tunnelViewModel: TunnelViewModel
    var activateOnDemandSetting: ActivateOnDemandSetting

    init(tunnelsManager tm: TunnelsManager, tunnel t: TunnelContainer) {
        // Use this initializer to edit an existing tunnel.
        tunnelsManager = tm
        tunnel = t
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: t.tunnelConfiguration())
        activateOnDemandSetting = t.activateOnDemandSetting()
        super.init(style: .grouped)
    }

    init(tunnelsManager tm: TunnelsManager, tunnelConfiguration: TunnelConfiguration?) {
        // Use this initializer to create a new tunnel.
        // If tunnelConfiguration is passed, data will be prepopulated from that configuration.
        tunnelsManager = tm
        tunnel = nil
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnelConfiguration)
        activateOnDemandSetting = ActivateOnDemandSetting.defaultSetting
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = (tunnel == nil) ? "New configuration" : "Edit configuration"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))

        self.tableView.rowHeight = 44

        self.tableView.register(TunnelEditTableViewKeyValueCell.self, forCellReuseIdentifier: TunnelEditTableViewKeyValueCell.id)
        self.tableView.register(TunnelEditTableViewReadOnlyKeyValueCell.self, forCellReuseIdentifier: TunnelEditTableViewReadOnlyKeyValueCell.id)
        self.tableView.register(TunnelEditTableViewButtonCell.self, forCellReuseIdentifier: TunnelEditTableViewButtonCell.id)
        self.tableView.register(TunnelEditTableViewSwitchCell.self, forCellReuseIdentifier: TunnelEditTableViewSwitchCell.id)
        self.tableView.register(TunnelEditTableViewSelectionListCell.self, forCellReuseIdentifier: TunnelEditTableViewSelectionListCell.id)
    }

    @objc func saveTapped() {
        self.tableView.endEditing(false)
        let tunnelSaveResult = tunnelViewModel.save()
        switch (tunnelSaveResult) {
        case .error(let errorMessage):
            let erroringConfiguration = (tunnelViewModel.interfaceData.validatedConfiguration == nil) ? "Interface" : "Peer"
            ErrorPresenter.showErrorAlert(title: "Invalid \(erroringConfiguration)", message: errorMessage, from: self)
            self.tableView.reloadData() // Highlight erroring fields
        case .saved(let tunnelConfiguration):
            if let tunnel = tunnel {
                // We're modifying an existing tunnel
                tunnelsManager.modify(tunnel: tunnel,
                                      tunnelConfiguration: tunnelConfiguration,
                                      activateOnDemandSetting: activateOnDemandSetting) { [weak self] (error) in
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
                                   activateOnDemandSetting: activateOnDemandSetting) { [weak self] (tunnel, error) in
                    if let error = error {
                        ErrorPresenter.showErrorAlert(error: error, from: self)
                    } else {
                        self?.dismiss(animated: true, completion: nil)
                        if let tunnel = tunnel {
                            self?.delegate?.tunnelSaved(tunnel: tunnel)
                        }
                    }
                }
            }
        }
    }

    @objc func cancelTapped() {
        dismiss(animated: true, completion: nil)
        self.delegate?.tunnelEditingCancelled()
    }

    func showErrorAlert(title: String, message: String) {
        let okAction = UIAlertAction(title: "OK", style: .default)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)

        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: UITableViewDataSource

extension TunnelEditTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        let numberOfInterfaceSections = interfaceFieldsBySection.count
        let numberOfPeerSections = tunnelViewModel.peersData.count

        return numberOfInterfaceSections + numberOfPeerSections + 1 /* Add Peer */ + 1 /* On-Demand */
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numberOfInterfaceSections = interfaceFieldsBySection.count
        let numberOfPeerSections = tunnelViewModel.peersData.count

        if (section < numberOfInterfaceSections) {
            // Interface
            return interfaceFieldsBySection[section].count
        } else if ((numberOfPeerSections > 0) && (section < (numberOfInterfaceSections + numberOfPeerSections))) {
            // Peer
            let peerIndex = (section - numberOfInterfaceSections)
            let peerData = tunnelViewModel.peersData[peerIndex]
            let peerFieldsToShow = peerData.shouldAllowExcludePrivateIPsControl ? peerFields : peerFields.filter { $0 != .excludePrivateIPs }
            return peerFieldsToShow.count
        } else if (section < (numberOfInterfaceSections + numberOfPeerSections + 1)) {
            // Add peer
            return 1
        } else {
            // On-Demand Rules
            if (activateOnDemandSetting.isActivateOnDemandEnabled) {
                return 4
            } else {
                return 1
            }
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let numberOfInterfaceSections = interfaceFieldsBySection.count
        let numberOfPeerSections = tunnelViewModel.peersData.count

        if (section < numberOfInterfaceSections) {
            // Interface
            return (section == 0) ? "Interface" : nil
        } else if ((numberOfPeerSections > 0) && (section < (numberOfInterfaceSections + numberOfPeerSections))) {
            // Peer
            return "Peer"
        } else if (section == (numberOfInterfaceSections + numberOfPeerSections)) {
            // Add peer
            return nil
        } else {
            assert(section == (numberOfInterfaceSections + numberOfPeerSections + 1))
            return "On-Demand Activation"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let numberOfInterfaceSections = interfaceFieldsBySection.count
        let numberOfPeerSections = tunnelViewModel.peersData.count

        let section = indexPath.section
        let row = indexPath.row

        if (section < numberOfInterfaceSections) {
            // Interface
            let interfaceData = tunnelViewModel.interfaceData
            let field = interfaceFieldsBySection[section][row]
            if (field == .generateKeyPair) {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelEditTableViewButtonCell.id, for: indexPath) as! TunnelEditTableViewButtonCell
                cell.buttonText = field.rawValue
                cell.onTapped = { [weak self, weak interfaceData] in
                    if let interfaceData = interfaceData, let s = self {
                        interfaceData[.privateKey] = Curve25519.generatePrivateKey().base64EncodedString()
                        if let privateKeyRow = s.interfaceFieldsBySection[section].firstIndex(of: .privateKey),
                            let publicKeyRow = s.interfaceFieldsBySection[section].firstIndex(of: .publicKey) {
                            let privateKeyIndex = IndexPath(row: privateKeyRow, section: section)
                            let publicKeyIndex = IndexPath(row: publicKeyRow, section: section)
                            s.tableView.reloadRows(at: [privateKeyIndex, publicKeyIndex], with: .automatic)
                        }
                    }
                }
                return cell
            } else if (field == .publicKey) {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelEditTableViewReadOnlyKeyValueCell.id, for: indexPath) as! TunnelEditTableViewReadOnlyKeyValueCell
                cell.key = field.rawValue
                cell.value = interfaceData[field]
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelEditTableViewKeyValueCell.id, for: indexPath) as! TunnelEditTableViewKeyValueCell
                // Set key
                cell.key = field.rawValue
                // Set placeholder text
                switch (field) {
                case .name:
                    cell.placeholderText = "Required"
                case .privateKey:
                    cell.placeholderText = "Required"
                case .addresses:
                    cell.placeholderText = "Optional"
                case .listenPort:
                    cell.placeholderText = "Automatic"
                case .mtu:
                    cell.placeholderText = "Automatic"
                case .dns:
                    cell.placeholderText = "Optional"
                case .publicKey: break
                case .generateKeyPair: break
                }
                // Set keyboardType
                if (field == .mtu || field == .listenPort) {
                    cell.keyboardType = .numberPad
                } else if (field == .addresses || field == .dns) {
                    cell.keyboardType = .numbersAndPunctuation
                }
                // Show erroring fields
                cell.isValueValid = (!interfaceData.fieldsWithError.contains(field))
                // Bind values to view model
                cell.value = interfaceData[field]
                if (field == .dns) { // While editing DNS, you might directly set exclude private IPs
                    cell.onValueBeingEdited = { [weak interfaceData] value in
                        interfaceData?[field] = value
                    }
                } else {
                    cell.onValueChanged = { [weak interfaceData] value in
                        interfaceData?[field] = value
                    }
                }
                // Compute public key live
                if (field == .privateKey) {
                    cell.onValueBeingEdited = { [weak self, weak interfaceData] value in
                        if let interfaceData = interfaceData, let s = self {
                            interfaceData[.privateKey] = value
                            if let row = s.interfaceFieldsBySection[section].firstIndex(of: .publicKey) {
                                s.tableView.reloadRows(at: [IndexPath(row: row, section: section)], with: .none)
                            }
                        }
                    }
                }
                return cell
            }
        } else if ((numberOfPeerSections > 0) && (section < (numberOfInterfaceSections + numberOfPeerSections))) {
            // Peer
            let peerIndex = (section - numberOfInterfaceSections)
            let peerData = tunnelViewModel.peersData[peerIndex]
            let peerFieldsToShow = peerData.shouldAllowExcludePrivateIPsControl ? peerFields : peerFields.filter { $0 != .excludePrivateIPs }
            let field = peerFieldsToShow[row]
            if (field == .deletePeer) {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelEditTableViewButtonCell.id, for: indexPath) as! TunnelEditTableViewButtonCell
                cell.buttonText = field.rawValue
                cell.hasDestructiveAction = true
                cell.onTapped = { [weak self, weak peerData] in
                    guard let peerData = peerData else { return }
                    guard let s = self else { return }
                    s.showConfirmationAlert(message: "Delete this peer?",
                                            buttonTitle: "Delete", from: cell,
                                            onConfirmed: { [weak s] in
                                                guard let s = s else { return }
                                                let removedSectionIndices = s.deletePeer(peer: peerData)
                                                let shouldShowExcludePrivateIPs = (s.tunnelViewModel.peersData.count == 1 &&
                                                    s.tunnelViewModel.peersData[0].shouldAllowExcludePrivateIPsControl)
                                                tableView.performBatchUpdates({
                                                    s.tableView.deleteSections(removedSectionIndices, with: .automatic)
                                                    if (shouldShowExcludePrivateIPs) {
                                                        if let row = s.peerFields.firstIndex(of: .excludePrivateIPs) {
                                                            let rowIndexPath = IndexPath(row: row, section: numberOfInterfaceSections /* First peer section */)
                                                            s.tableView.insertRows(at: [rowIndexPath], with: .automatic)
                                                        }

                                                    }
                                                })
                    })
                }
                return cell
            } else if (field == .excludePrivateIPs) {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelEditTableViewSwitchCell.id, for: indexPath) as! TunnelEditTableViewSwitchCell
                cell.message = field.rawValue
                cell.isEnabled = peerData.shouldAllowExcludePrivateIPsControl
                cell.isOn = peerData.excludePrivateIPsValue
                cell.onSwitchToggled = { [weak self] (isOn) in
                    guard let s = self else { return }
                    peerData.excludePrivateIPsValueChanged(isOn: isOn, dnsServers: s.tunnelViewModel.interfaceData[.dns])
                    if let row = s.peerFields.firstIndex(of: .allowedIPs) {
                        s.tableView.reloadRows(at: [IndexPath(row: row, section: section)], with: .none)
                    }
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelEditTableViewKeyValueCell.id, for: indexPath) as! TunnelEditTableViewKeyValueCell
                // Set key
                cell.key = field.rawValue
                // Set placeholder text
                switch (field) {
                case .publicKey:
                    cell.placeholderText = "Required"
                case .preSharedKey:
                    cell.placeholderText = "Optional"
                case .endpoint:
                    cell.placeholderText = "Optional"
                case .allowedIPs:
                    cell.placeholderText = "Optional"
                case .persistentKeepAlive:
                    cell.placeholderText = "Off"
                case .excludePrivateIPs: break
                case .deletePeer: break
                }
                // Set keyboardType
                if (field == .persistentKeepAlive) {
                    cell.keyboardType = .numberPad
                } else if (field == .allowedIPs) {
                    cell.keyboardType = .numbersAndPunctuation
                }
                // Show erroring fields
                cell.isValueValid = (!peerData.fieldsWithError.contains(field))
                // Bind values to view model
                cell.value = peerData[field]
                if (field != .allowedIPs) {
                    cell.onValueChanged = { [weak peerData] value in
                        peerData?[field] = value
                    }
                }
                // Compute state of exclude private IPs live
                if (field == .allowedIPs) {
                    cell.onValueBeingEdited = { [weak self, weak peerData] value in
                        if let peerData = peerData, let s = self {
                            let oldValue = peerData.shouldAllowExcludePrivateIPsControl
                            peerData[.allowedIPs] = value
                            if (oldValue != peerData.shouldAllowExcludePrivateIPsControl) {
                                if let row = s.peerFields.firstIndex(of: .excludePrivateIPs) {
                                    if (peerData.shouldAllowExcludePrivateIPsControl) {
                                        s.tableView.insertRows(at: [IndexPath(row: row, section: section)], with: .automatic)
                                    } else {
                                        s.tableView.deleteRows(at: [IndexPath(row: row, section: section)], with: .automatic)
                                    }
                                }
                            }
                        }
                    }
                }
                return cell
            }
        } else if (section == (numberOfInterfaceSections + numberOfPeerSections)) {
            // Add peer
            let cell = tableView.dequeueReusableCell(withIdentifier: TunnelEditTableViewButtonCell.id, for: indexPath) as! TunnelEditTableViewButtonCell
            cell.buttonText = "Add peer"
            cell.onTapped = { [weak self] in
                guard let s = self else { return }
                let shouldHideExcludePrivateIPs = (s.tunnelViewModel.peersData.count == 1 &&
                    s.tunnelViewModel.peersData[0].shouldAllowExcludePrivateIPsControl)
                let addedSectionIndices = s.appendEmptyPeer()
                tableView.performBatchUpdates({
                    tableView.insertSections(addedSectionIndices, with: .automatic)
                    if (shouldHideExcludePrivateIPs) {
                        if let row = s.peerFields.firstIndex(of: .excludePrivateIPs) {
                            let rowIndexPath = IndexPath(row: row, section: numberOfInterfaceSections /* First peer section */)
                            s.tableView.deleteRows(at: [rowIndexPath], with: .automatic)
                        }
                    }
                }, completion: nil)
            }
            return cell
        } else {
            assert(section == (numberOfInterfaceSections + numberOfPeerSections + 1))
            if (row == 0) {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelEditTableViewSwitchCell.id, for: indexPath) as! TunnelEditTableViewSwitchCell
                cell.message = "Activate on demand"
                cell.isOn = activateOnDemandSetting.isActivateOnDemandEnabled
                cell.onSwitchToggled = { [weak self] (isOn) in
                    guard let s = self else { return }
                    let indexPaths: [IndexPath] = (1 ..< 4).map { IndexPath(row: $0, section: section) }
                    if (isOn) {
                        s.activateOnDemandSetting.isActivateOnDemandEnabled = true
                        if (s.activateOnDemandSetting.activateOnDemandOption == .none) {
                            s.activateOnDemandSetting.activateOnDemandOption = s.tunnelViewModel.defaultActivateOnDemandOption()
                        }
                        s.tableView.insertRows(at: indexPaths, with: .automatic)
                    } else {
                        s.activateOnDemandSetting.isActivateOnDemandEnabled = false
                        s.tableView.deleteRows(at: indexPaths, with: .automatic)
                    }
                }
                return cell
            } else {
                assert(row < 4)
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelEditTableViewSelectionListCell.id, for: indexPath) as! TunnelEditTableViewSelectionListCell
                let rowOption = activateOnDemandOptions[row - 1]
                let selectedOption = activateOnDemandSetting.activateOnDemandOption
                assert(selectedOption != .none)
                cell.message = tunnelViewModel.activateOnDemandOptionText(for: rowOption)
                cell.isChecked = (selectedOption == rowOption)
                return cell
            }
        }
    }

    func appendEmptyPeer() -> IndexSet {
        let numberOfInterfaceSections = interfaceFieldsBySection.count

        tunnelViewModel.appendEmptyPeer()
        let addedPeerIndex = tunnelViewModel.peersData.count - 1

        let addedSectionIndices = IndexSet(integer: (numberOfInterfaceSections + addedPeerIndex))
        return addedSectionIndices
    }

    func deletePeer(peer: TunnelViewModel.PeerData) -> IndexSet {
        let numberOfInterfaceSections = interfaceFieldsBySection.count

        assert(peer.index < tunnelViewModel.peersData.count)
        tunnelViewModel.deletePeer(peer: peer)

        let removedSectionIndices = IndexSet(integer: (numberOfInterfaceSections + peer.index))
        return removedSectionIndices
    }

    func showConfirmationAlert(message: String, buttonTitle: String, from sourceView: UIView,
                               onConfirmed: @escaping (() -> Void)) {
        let destroyAction = UIAlertAction(title: buttonTitle, style: .destructive) { (_) in
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

// MARK: UITableViewDelegate

extension TunnelEditTableViewController {
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let numberOfInterfaceSections = interfaceFieldsBySection.count
        let numberOfPeerSections = tunnelViewModel.peersData.count

        let section = indexPath.section
        let row = indexPath.row

        if (section == (numberOfInterfaceSections + numberOfPeerSections + 1)) {
            return (row > 0) ? indexPath : nil
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let numberOfInterfaceSections = interfaceFieldsBySection.count
        let numberOfPeerSections = tunnelViewModel.peersData.count

        let section = indexPath.section
        let row = indexPath.row

        assert(section == (numberOfInterfaceSections + numberOfPeerSections + 1))
        assert(row > 0)

        let option = activateOnDemandOptions[row - 1]
        assert(option != .none)
        activateOnDemandSetting.activateOnDemandOption = option

        let indexPaths: [IndexPath] = (1 ..< 4).map { IndexPath(row: $0, section: section) }
        tableView.reloadRows(at: indexPaths, with: .automatic)
    }
}

class TunnelEditTableViewKeyValueCell: UITableViewCell {
    static let id: String = "TunnelEditTableViewKeyValueCell"
    var key: String {
        get { return keyLabel.text ?? "" }
        set(value) {keyLabel.text = value }
    }
    var value: String {
        get { return valueTextField.text ?? "" }
        set(value) { valueTextField.text = value }
    }
    var placeholderText: String {
        get { return valueTextField.placeholder ?? "" }
        set(value) { valueTextField.placeholder = value }
    }
    var isValueValid: Bool = true {
        didSet {
            if (isValueValid) {
                keyLabel.textColor = UIColor.black
            } else {
                keyLabel.textColor = UIColor.red
            }
        }
    }
    var keyboardType: UIKeyboardType {
        get { return valueTextField.keyboardType }
        set(value) { valueTextField.keyboardType = value }
    }

    var onValueChanged: ((String) -> Void)?
    var onValueBeingEdited: ((String) -> Void)?

    let keyLabel: UILabel
    let valueTextField: UITextField

    private var textFieldValueOnBeginEditing: String = ""

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        keyLabel = UILabel()
        valueTextField = UITextField()
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(keyLabel)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        keyLabel.textAlignment = .right
        let widthRatioConstraint = NSLayoutConstraint(item: keyLabel, attribute: .width,
                                                      relatedBy: .equal,
                                                      toItem: self, attribute: .width,
                                                      multiplier: 0.4, constant: 0)
        // The "Persistent Keepalive" key doesn't fit into 0.4 * width on the iPhone SE,
        // so set a CR priority > the 0.4-constraint's priority.
        widthRatioConstraint.priority = .defaultHigh + 1
        keyLabel.setContentCompressionResistancePriority(.defaultHigh + 2, for: .horizontal)
        NSLayoutConstraint.activate([
            keyLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            keyLabel.leftAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leftAnchor),
            widthRatioConstraint
            ])
        contentView.addSubview(valueTextField)
        valueTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueTextField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueTextField.leftAnchor.constraint(equalTo: keyLabel.rightAnchor, constant: 16),
            valueTextField.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor),
            ])
        valueTextField.delegate = self

        valueTextField.autocapitalizationType = .none
        valueTextField.autocorrectionType = .no
        valueTextField.spellCheckingType = .no
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        key = ""
        value = ""
        placeholderText = ""
        isValueValid = true
        keyboardType = .default
        onValueChanged = nil
        onValueBeingEdited = nil
    }
}

extension TunnelEditTableViewKeyValueCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textFieldValueOnBeginEditing = textField.text ?? ""
        isValueValid = true
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        let isModified = (textField.text ?? "" != textFieldValueOnBeginEditing)
        guard (isModified) else { return }
        if let onValueChanged = onValueChanged {
            onValueChanged(textField.text ?? "")
        }
    }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let onValueBeingEdited = onValueBeingEdited {
            let modifiedText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
            onValueBeingEdited(modifiedText)
        }
        return true
    }
}

class TunnelEditTableViewReadOnlyKeyValueCell: CopyableLabelTableViewCell {
    static let id: String = "TunnelEditTableViewReadOnlyKeyValueCell"
    var key: String {
        get { return keyLabel.text ?? "" }
        set(value) {keyLabel.text = value }
    }
    var value: String {
        get { return valueLabel.text }
        set(value) { valueLabel.text = value }
    }

    let keyLabel: UILabel
    let valueLabel: ScrollableLabel

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        keyLabel = UILabel()
        valueLabel = ScrollableLabel()

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        keyLabel.textColor = UIColor.gray
        valueLabel.textColor = UIColor.gray

        contentView.addSubview(keyLabel)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        keyLabel.textAlignment = .right
        let widthRatioConstraint = NSLayoutConstraint(item: keyLabel, attribute: .width,
                                                      relatedBy: .equal,
                                                      toItem: self, attribute: .width,
                                                      multiplier: 0.4, constant: 0)
        // In case the key doesn't fit into 0.4 * width,
        // so set a CR priority > the 0.4-constraint's priority.
        widthRatioConstraint.priority = .defaultHigh + 1
        keyLabel.setContentCompressionResistancePriority(.defaultHigh + 2, for: .horizontal)
        NSLayoutConstraint.activate([
            keyLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            keyLabel.leftAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leftAnchor),
            widthRatioConstraint
            ])

        contentView.addSubview(valueLabel)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.leftAnchor.constraint(equalTo: keyLabel.rightAnchor, constant: 16),
            valueLabel.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor),
            ])
    }

    override var textToCopy: String? {
        return self.valueLabel.text
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        key = ""
        value = ""
    }
}

class TunnelEditTableViewButtonCell: UITableViewCell {
    static let id: String = "TunnelEditTableViewButtonCell"
    var buttonText: String {
        get { return button.title(for: .normal) ?? "" }
        set(value) { button.setTitle(value, for: .normal) }
    }
    var hasDestructiveAction: Bool {
        get { return button.tintColor == UIColor.red }
        set(value) { button.tintColor = value ? UIColor.red : buttonStandardTintColor }
    }
    var onTapped: (() -> Void)?

    let button: UIButton
    var buttonStandardTintColor: UIColor

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        button = UIButton(type: .system)
        buttonStandardTintColor = button.tintColor
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            button.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
            ])
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    @objc func buttonTapped() {
        onTapped?()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        buttonText = ""
        onTapped = nil
        hasDestructiveAction = false
    }
}

class TunnelEditTableViewSwitchCell: UITableViewCell {
    static let id: String = "TunnelEditTableViewSwitchCell"
    var message: String {
        get { return textLabel?.text ?? "" }
        set(value) { textLabel!.text = value }
    }
    var isOn: Bool {
        get { return switchView.isOn }
        set(value) { switchView.isOn = value }
    }
    var isEnabled: Bool {
        get { return switchView.isEnabled }
        set(value) {
            switchView.isEnabled = value
            textLabel?.textColor = value ? UIColor.black : UIColor.gray
        }
    }

    var onSwitchToggled: ((Bool) -> Void)?

    let switchView: UISwitch

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        switchView = UISwitch()
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        accessoryView = switchView

        switchView.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
    }

    @objc func switchToggled() {
        onSwitchToggled?(switchView.isOn)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        message = ""
        isOn = false
    }
}

class TunnelEditTableViewSelectionListCell: UITableViewCell {
    static let id: String = "TunnelEditTableViewSelectionListCell"
    var message: String {
        get { return textLabel?.text ?? "" }
        set(value) { textLabel!.text = value }
    }
    var isChecked: Bool {
        didSet {
            accessoryType = isChecked ? .checkmark : .none
        }
    }
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        isChecked = false
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        message = ""
        isChecked = false
    }
}
