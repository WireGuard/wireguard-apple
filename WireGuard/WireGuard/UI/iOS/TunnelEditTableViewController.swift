// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import UIKit

protocol TunnelEditTableViewControllerDelegate: class {
    func saved(tunnel: TunnelContainer)
}

// MARK: TunnelEditTableViewController

class TunnelEditTableViewController: UITableViewController {

    weak var delegate: TunnelEditTableViewControllerDelegate? = nil

    let interfaceFieldsBySection: [[TunnelViewModel.InterfaceField]] = [
        [.name],
        [.privateKey, .publicKey, .generateKeyPair],
        [.addresses, .listenPort, .mtu, .dns]
    ]

    let peerFieldsBySection: [[TunnelViewModel.PeerField]] = [
        [.publicKey, .preSharedKey, .endpoint,
         .allowedIPs, .persistentKeepAlive,
         .deletePeer]
    ]

    let tunnelsManager: TunnelsManager
    let tunnel: TunnelContainer?
    let tunnelViewModel: TunnelViewModel

    init(tunnelsManager tm: TunnelsManager, tunnel t: TunnelContainer) {
        // Use this initializer to edit an existing tunnel.
        tunnelsManager = tm
        tunnel = t
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: t.tunnelConfiguration)
        super.init(style: .grouped)
        self.modalPresentationStyle = .formSheet
    }

    init(tunnelsManager tm: TunnelsManager, tunnelConfiguration: TunnelConfiguration?) {
        // Use this initializer to create a new tunnel.
        // If tunnelConfiguration is passed, data will be prepopulated from that configuration.
        tunnelsManager = tm
        tunnel = nil
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnelConfiguration)
        super.init(style: .grouped)
        self.modalPresentationStyle = .formSheet
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "New configuration"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))

        self.tableView.rowHeight = 44
        self.tableView.allowsSelection = false

        self.tableView.register(TunnelsEditTableViewKeyValueCell.self, forCellReuseIdentifier: TunnelsEditTableViewKeyValueCell.id)
        self.tableView.register(TunnelsEditTableViewButtonCell.self, forCellReuseIdentifier: TunnelsEditTableViewButtonCell.id)
        self.tableView.register(TunnelsEditTableViewSwitchCell.self, forCellReuseIdentifier: TunnelsEditTableViewSwitchCell.id)
    }

    @objc func saveTapped() {
        self.tableView.endEditing(false)
        let tunnelSaveResult = tunnelViewModel.save()
        switch (tunnelSaveResult) {
        case .error(let errorMessage):
            let erroringConfiguration = (tunnelViewModel.interfaceData.validatedConfiguration == nil) ? "Interface" : "Peer"
            showErrorAlert(title: "Invalid \(erroringConfiguration)", message: errorMessage)
        case .saved(let tunnelConfiguration):
            if let tunnel = tunnel {
                // We're modifying an existing tunnel
                tunnelsManager.modify(tunnel: tunnel, with: tunnelConfiguration) { [weak self] (error) in
                    if let error = error {
                        print("Could not modify tunnel: \(error)")
                        self?.showErrorAlert(title: "Could not save", message: "Internal error")
                    } else {
                        self?.delegate?.saved(tunnel: tunnel)
                        self?.dismiss(animated: true, completion: nil)
                    }
                }
            } else {
                // We're adding a new tunnel
                tunnelsManager.add(tunnelConfiguration: tunnelConfiguration) { [weak self] (tunnel, error) in
                    if let error = error {
                        print("Could not add tunnel: \(error)")
                        self?.showErrorAlert(title: "Could not save", message: "Internal error")
                    } else {
                        self?.delegate?.saved(tunnel: tunnel)
                        self?.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }

    @objc func cancelTapped() {
        dismiss(animated: true, completion: nil)
    }

    func showErrorAlert(title: String, message: String) {
        let okAction = UIAlertAction(title: "Ok", style: .default)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)

        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: UITableViewDataSource

extension TunnelEditTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        let numberOfInterfaceSections = interfaceFieldsBySection.count
        let numberOfPeerSections = peerFieldsBySection.count
        let numberOfPeers = tunnelViewModel.peersData.count

        return numberOfInterfaceSections + (numberOfPeers * numberOfPeerSections) + 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numberOfInterfaceSections = interfaceFieldsBySection.count
        let numberOfPeerSections = peerFieldsBySection.count
        let numberOfPeers = tunnelViewModel.peersData.count

        if (section < numberOfInterfaceSections) {
            // Interface
            return interfaceFieldsBySection[section].count
        } else if ((numberOfPeers > 0) && (section < (numberOfInterfaceSections + numberOfPeers * numberOfPeerSections))) {
            // Peer
            let fieldIndex = (section - numberOfInterfaceSections) % numberOfPeerSections
            return peerFieldsBySection[fieldIndex].count
        } else {
            // Add peer
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let numberOfInterfaceSections = interfaceFieldsBySection.count
        let numberOfPeerSections = peerFieldsBySection.count
        let numberOfPeers = tunnelViewModel.peersData.count

        if (section < numberOfInterfaceSections) {
            // Interface
            return (section == 0) ? "Interface" : nil
        } else if ((numberOfPeers > 0) && (section < (numberOfInterfaceSections + numberOfPeers * numberOfPeerSections))) {
            // Peer
            let fieldIndex = (section - numberOfInterfaceSections) % numberOfPeerSections
            return (fieldIndex == 0) ? "Peer" : nil
        } else {
            // Add peer
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let numberOfInterfaceSections = interfaceFieldsBySection.count
        let numberOfPeerSections = peerFieldsBySection.count
        let numberOfPeers = tunnelViewModel.peersData.count

        let section = indexPath.section
        let row = indexPath.row

        if (section < numberOfInterfaceSections) {
            // Interface
            let interfaceData = tunnelViewModel.interfaceData
            let field = interfaceFieldsBySection[section][row]
            if (field == .generateKeyPair) {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelsEditTableViewButtonCell.id, for: indexPath) as! TunnelsEditTableViewButtonCell
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
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelsEditTableViewKeyValueCell.id, for: indexPath) as! TunnelsEditTableViewKeyValueCell
                // Set key
                cell.key = field.rawValue
                // Set placeholder text
                if (field == .name || field == .privateKey) {
                    cell.placeholderText = "Required"
                } else if (field == .mtu) {
                    cell.placeholderText = "Automatic"
                }
                // Set editable
                if (field == .publicKey) {
                    cell.isValueEditable = false
                }
                // Bind values to view model
                cell.value = interfaceData[field]
                cell.onValueChanged = { [weak interfaceData] value in
                    interfaceData?[field] = value
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
        } else if ((numberOfPeers > 0) && (section < (numberOfInterfaceSections + numberOfPeers * numberOfPeerSections))) {
            // Peer
            let peerIndex = Int((section - numberOfInterfaceSections) / numberOfPeerSections)
            let peerSectionIndex = (section - numberOfInterfaceSections) % numberOfPeerSections
            let peerData = tunnelViewModel.peersData[peerIndex]
            let field = peerFieldsBySection[peerSectionIndex][row]
            if (field == .deletePeer) {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelsEditTableViewButtonCell.id, for: indexPath) as! TunnelsEditTableViewButtonCell
                cell.buttonText = field.rawValue
                cell.onTapped = { [weak self, weak peerData] in
                    guard let peerData = peerData else { return }
                    guard let s = self else { return }
                    s.showConfirmationAlert(message: "Delete this peer?",
                                            buttonTitle: "Delete", from: cell,
                                            onConfirmed: { [weak s] in
                                                guard let s = s else { return }
                                                let removedSectionIndices = s.deletePeer(peer: peerData)
                                                s.tableView.deleteSections(removedSectionIndices, with: .automatic)
                    })
                }
                return cell
            } else if (field == .excludePrivateIPs) {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelsEditTableViewSwitchCell.id, for: indexPath) as! TunnelsEditTableViewSwitchCell
                cell.message = field.rawValue
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelsEditTableViewKeyValueCell.id, for: indexPath) as! TunnelsEditTableViewKeyValueCell
                // Set key
                cell.key = field.rawValue
                // Set placeholder text
                if (field == .publicKey) {
                    cell.placeholderText = "Required"
                }
                // Bind values to view model
                cell.value = peerData[field]
                cell.onValueChanged = { [weak peerData] value in
                    peerData?[field] = value
                }
                return cell
            }
        } else {
            assert(section == (numberOfInterfaceSections + numberOfPeers * numberOfPeerSections))
            // Add peer
            let cell = tableView.dequeueReusableCell(withIdentifier: TunnelsEditTableViewButtonCell.id, for: indexPath) as! TunnelsEditTableViewButtonCell
            cell.buttonText = "Add peer"
            cell.onTapped = { [weak self] in
                guard let s = self else { return }
                let addedSectionIndices = s.appendEmptyPeer()
                tableView.insertSections(addedSectionIndices, with: .automatic)
            }
            return cell
        }
    }

    func appendEmptyPeer() -> IndexSet {
        let numberOfInterfaceSections = interfaceFieldsBySection.count
        let numberOfPeerSections = peerFieldsBySection.count

        tunnelViewModel.appendEmptyPeer()
        let addedPeerIndex = tunnelViewModel.peersData.count - 1

        let firstAddedSectionIndex = (numberOfInterfaceSections + addedPeerIndex * numberOfPeerSections)
        let addedSectionIndices = IndexSet(integersIn: firstAddedSectionIndex ..< firstAddedSectionIndex + numberOfPeerSections)
        return addedSectionIndices
    }

    func deletePeer(peer: TunnelViewModel.PeerData) -> IndexSet {
        let numberOfInterfaceSections = interfaceFieldsBySection.count
        let numberOfPeerSections = peerFieldsBySection.count

        assert(peer.index < tunnelViewModel.peersData.count)
        tunnelViewModel.deletePeer(peer: peer)

        let firstRemovedSectionIndex = (numberOfInterfaceSections + peer.index * numberOfPeerSections)
        let removedSectionIndices = IndexSet(integersIn: firstRemovedSectionIndex ..< firstRemovedSectionIndex + numberOfPeerSections)
        return removedSectionIndices
    }

    func showConfirmationAlert(message: String, buttonTitle: String, from sourceView: UIView,
                               onConfirmed: @escaping (() -> Void)) {
        let destroyAction = UIAlertAction(title: buttonTitle, style: .destructive) { (action) in
            onConfirmed()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let alert = UIAlertController(title: "", message: message, preferredStyle: .actionSheet)
        alert.addAction(destroyAction)
        alert.addAction(cancelAction)

        // popoverPresentationController will be nil on iPhone and non-nil on iPad
        alert.popoverPresentationController?.sourceView = sourceView

        self.present(alert, animated: true, completion: nil)
    }
}

class TunnelsEditTableViewKeyValueCell: UITableViewCell {
    static let id: String = "TunnelsEditTableViewKeyValueCell"
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
    var isValueEditable: Bool {
        get { return valueTextField.isEnabled }
        set(value) {
            valueTextField.isEnabled = value
            keyLabel.textColor = value ? UIColor.black : UIColor.gray
            valueTextField.textColor = value ? UIColor.black : UIColor.gray
        }
    }
    var isValueValid: Bool = true {
        didSet(value) {
            if (value) {
                keyLabel.textColor = isValueEditable ? UIColor.black : UIColor.gray
            } else {
                keyLabel.textColor = UIColor.red
            }
        }
    }

    var onValueChanged: ((String) -> Void)? = nil
    var onValueBeingEdited: ((String) -> Void)? = nil

    let keyLabel: UILabel
    let valueTextField: UITextField

    private var textFieldValueOnBeginEditing: String = ""

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
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
            keyLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 8),
            widthRatioConstraint
            ])
        contentView.addSubview(valueTextField)
        valueTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueTextField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueTextField.leftAnchor.constraint(equalTo: keyLabel.rightAnchor, constant: 16),
            valueTextField.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -8),
            ])
        valueTextField.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        key = ""
        value = ""
        placeholderText = ""
        isValueEditable = true
        isValueValid = true
        onValueChanged = nil
    }
}

extension TunnelsEditTableViewKeyValueCell: UITextFieldDelegate {
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

class TunnelsEditTableViewButtonCell: UITableViewCell {
    static let id: String = "TunnelsEditTableViewButtonCell"
    var buttonText: String {
        get { return button.title(for: .normal) ?? "" }
        set(value) { button.setTitle(value, for: .normal) }
    }
    var onTapped: (() -> Void)? = nil

    let button: UIButton

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        button = UIButton(type: .system)
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
        buttonText = ""
        onTapped = nil
    }
}

class TunnelsEditTableViewSwitchCell: UITableViewCell {
    static let id: String = "TunnelsEditTableViewSwitchCell"
    var message: String {
        get { return textLabel?.text ?? "" }
        set(value) { textLabel!.text = value }
    }
    var isOn: Bool {
        get { return switchView.isOn }
        set(value) { switchView.isOn = value }
    }

    let switchView: UISwitch

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        switchView = UISwitch()
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        accessoryView = switchView
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        message = ""
        isOn = false
    }
}
