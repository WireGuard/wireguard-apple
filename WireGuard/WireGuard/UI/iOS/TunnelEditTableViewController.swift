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
        self.title = tunnel == nil ? "New configuration" : "Edit configuration"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))

        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension

        self.tableView.register(KeyValueCell.self)
        self.tableView.register(ReadOnlyKeyValueCell.self)
        self.tableView.register(ButtonCell.self)
        self.tableView.register(SwitchCell.self)
        self.tableView.register(SelectionListCell.self)
    }

    private func loadSections() {
        sections.removeAll()
        interfaceFieldsBySection.forEach { _ in sections.append(.interface) }
        tunnelViewModel.peersData.forEach { sections.append(.peer($0)) }
        sections.append(.addPeer)
        sections.append(.onDemand)
    }

    @objc func saveTapped() {
        self.tableView.endEditing(false)
        let tunnelSaveResult = tunnelViewModel.save()
        switch tunnelSaveResult {
        case .error(let errorMessage):
            let erroringConfiguration = (tunnelViewModel.interfaceData.validatedConfiguration == nil) ? "Interface" : "Peer"
            ErrorPresenter.showErrorAlert(title: "Invalid \(erroringConfiguration)", message: errorMessage, from: self)
            self.tableView.reloadData() // Highlight erroring fields
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
        self.delegate?.tunnelEditingCancelled()
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
        let cell: ReadOnlyKeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.rawValue
        cell.value = tunnelViewModel.interfaceData[field]
        return cell
    }

    private func interfaceFieldKeyValueCell(for tableView: UITableView, at indexPath: IndexPath, with field: TunnelViewModel.InterfaceField) -> UITableViewCell {
        let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
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
            cell.onValueChanged = nil
            cell.onValueBeingEdited = { [weak self] value in
                self?.tunnelViewModel.interfaceData[field] = value
            }
        } else {
            cell.onValueChanged = { [weak self] value in
                self?.tunnelViewModel.interfaceData[field] = value
            }
            cell.onValueBeingEdited = nil
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
        } else {
            cell.onValueBeingEdited = nil
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
        let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.rawValue

        switch field {
        case .publicKey:
            cell.placeholderText = "Required"
        case .preSharedKey, .endpoint, .allowedIPs:
            cell.placeholderText = "Optional"
        case .persistentKeepAlive:
            cell.placeholderText = "Off"
        case .excludePrivateIPs, .deletePeer:
            break
        }
        
        switch field {
        case .persistentKeepAlive:
            cell.keyboardType = .numberPad
        case .allowedIPs:
            cell.keyboardType = .numbersAndPunctuation
        default:
            cell.keyboardType = .default
        }

        // Show erroring fields
        cell.isValueValid = (!peerData.fieldsWithError.contains(field))
        // Bind values to view model
        cell.value = peerData[field]
        if field != .allowedIPs {
            cell.onValueChanged = { [weak peerData] value in
                peerData?[field] = value
            }
        }
        // Compute state of exclude private IPs live
        if field == .allowedIPs {
            cell.onValueBeingEdited = { [weak self, weak peerData] value in
                if let peerData = peerData, let self = self {
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
            }
        } else {
            cell.onValueBeingEdited = nil
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
                let indexPaths: [IndexPath] = (1 ..< 4).map { IndexPath(row: $0, section: indexPath.section) }
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
            let cell: SelectionListCell = tableView.dequeueReusableCell(for: indexPath)
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

        // popoverPresentationController will be nil on iPhone and non-nil on iPad
        alert.popoverPresentationController?.sourceView = sourceView
        alert.popoverPresentationController?.sourceRect = sourceView.bounds

        self.present(alert, animated: true, completion: nil)
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

private class KeyValueCell: UITableViewCell {
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
            if isValueValid {
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

    var isStackedHorizontally: Bool = false
    var isStackedVertically: Bool = false
    var contentSizeBasedConstraints: [NSLayoutConstraint] = []

    private var textFieldValueOnBeginEditing: String = ""

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        keyLabel = UILabel()
        keyLabel.font = UIFont.preferredFont(forTextStyle: .body)
        keyLabel.adjustsFontForContentSizeCategory = true
        valueTextField = UITextField()
        valueTextField.font = UIFont.preferredFont(forTextStyle: .body)
        valueTextField.adjustsFontForContentSizeCategory = true
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
            keyLabel.leftAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leftAnchor),
            keyLabel.topAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.topAnchor, multiplier: 0.5),
            widthRatioConstraint
        ])
        contentView.addSubview(valueTextField)
        valueTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueTextField.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor),
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: valueTextField.bottomAnchor, multiplier: 0.5)
        ])
        valueTextField.delegate = self

        valueTextField.autocapitalizationType = .none
        valueTextField.autocorrectionType = .no
        valueTextField.spellCheckingType = .no

        configureForContentSize()
    }

    func configureForContentSize() {
        var constraints: [NSLayoutConstraint] = []
        if self.traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            // Stack vertically
            if !isStackedVertically {
                constraints = [
                    valueTextField.topAnchor.constraint(equalToSystemSpacingBelow: keyLabel.bottomAnchor, multiplier: 0.5),
                    valueTextField.leftAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leftAnchor),
                    keyLabel.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor)
                ]
                isStackedVertically = true
                isStackedHorizontally = false
            }
        } else {
            // Stack horizontally
            if !isStackedHorizontally {
                constraints = [
                    contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: keyLabel.bottomAnchor, multiplier: 0.5),
                    valueTextField.leftAnchor.constraint(equalToSystemSpacingAfter: keyLabel.rightAnchor, multiplier: 1),
                    valueTextField.topAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.topAnchor, multiplier: 0.5)
                ]
                isStackedHorizontally = true
                isStackedVertically = false
            }
        }
        if !constraints.isEmpty {
            NSLayoutConstraint.deactivate(self.contentSizeBasedConstraints)
            NSLayoutConstraint.activate(constraints)
            self.contentSizeBasedConstraints = constraints
        }
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
        configureForContentSize()
    }
}

extension KeyValueCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textFieldValueOnBeginEditing = textField.text ?? ""
        isValueValid = true
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        let isModified = (textField.text ?? "" != textFieldValueOnBeginEditing)
        guard isModified else { return }
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

private class ReadOnlyKeyValueCell: CopyableLabelTableViewCell {
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
        keyLabel.font = UIFont.preferredFont(forTextStyle: .body)
        keyLabel.adjustsFontForContentSizeCategory = true
        valueLabel = ScrollableLabel()
        valueLabel.label.font = UIFont.preferredFont(forTextStyle: .body)
        valueLabel.label.adjustsFontForContentSizeCategory = true

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
            valueLabel.leftAnchor.constraint(equalToSystemSpacingAfter: keyLabel.rightAnchor, multiplier: 1),
            valueLabel.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor)
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

private class ButtonCell: UITableViewCell {
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
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        buttonStandardTintColor = button.tintColor
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: button.bottomAnchor),
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

private class SwitchCell: UITableViewCell {
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

private class SelectionListCell: UITableViewCell {
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
