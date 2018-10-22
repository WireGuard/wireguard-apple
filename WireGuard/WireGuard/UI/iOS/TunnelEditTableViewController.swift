//
//  TunnelEditTableViewController.swift
//  WireGuard
//
//  Created by Roopesh Chander on 17/10/18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import UIKit

// MARK: TunnelEditTableViewController

class TunnelEditTableViewController: UITableViewController {

    // MARK: View model

    enum InterfaceEditField: String {
        case name = "Name"
        case privateKey = "Private key"
        case publicKey = "Public key"
        case generateKeyPair = "Generate keypair"
        case addresses = "Addresses"
        case listenPort = "Listen port"
        case mtu = "MTU"
        case dns = "DNS servers"
    }

    let interfaceEditFieldsBySection: [[InterfaceEditField]] = [
        [.name],
        [.privateKey, .publicKey, .generateKeyPair],
        [.addresses, .listenPort, .mtu, .dns]
    ]

    enum PeerEditField: String {
        case publicKey = "Public key"
        case preSharedKey = "Pre-shared key"
        case endpoint = "Endpoint"
        case persistentKeepAlive = "Persistent Keepalive"
        case allowedIPs = "Allowed IPs"
        case excludePrivateIPs = "Exclude private IPs"
        case deletePeer = "Delete peer"
    }

    let peerEditFieldsBySection: [[PeerEditField]] = [
        [.publicKey, .preSharedKey, .endpoint,
         .allowedIPs, .excludePrivateIPs,
         .persistentKeepAlive,
         .deletePeer]
    ]

    // Scratchpad for entered data

    class InterfaceData {
        var scratchpad: [InterfaceEditField: String] = [:]
        var fieldsWithError: Set<InterfaceEditField> = []
        var validatedConfiguration: InterfaceConfiguration? = nil
        subscript(field: InterfaceEditField) -> String {
            get {
                ensureScratchpadIsPrepared() // When starting to read a config, setup the scratchpad to serve as a cache
                return scratchpad[field] ?? ""
            }
            set(stringValue) {
                ensureScratchpadIsPrepared() // When starting to edit a config, setup the scratchpad
                validatedConfiguration = nil // The configuration will need to be revalidated
                if (stringValue.isEmpty) {
                    scratchpad.removeValue(forKey: field)
                } else {
                    scratchpad[field] = stringValue
                }
            }
        }
        func ensureScratchpadIsPrepared() {
            guard (scratchpad.isEmpty) else { return } // Already prepared
            guard let config = validatedConfiguration else { return } // Nothing to prepare it with
            scratchpad[.name] = config.name
            scratchpad[.privateKey] = config.privateKey.base64EncodedString()
            if (!config.addresses.isEmpty) {
                scratchpad[.addresses] = config.addresses.map { $0.stringRepresentation() }.joined(separator: ", ")
            }
            if let listenPort = config.listenPort {
                scratchpad[.listenPort] = String(listenPort)
            }
            if let mtu = config.mtu {
                scratchpad[.mtu] = String(mtu)
            }
            if let dns = config.dns {
                scratchpad[.dns] = String(dns)
            }
        }
        func validate() -> (success: Bool, errorMessage: String) {
            var firstErrorMessage: String? = nil
            func setErrorMessage(_ errorMessage: String) {
                if (firstErrorMessage == nil) {
                    firstErrorMessage = errorMessage
                }
            }
            fieldsWithError.removeAll()
            guard let name = scratchpad[.name] else {
                fieldsWithError.insert(.name)
                return(false, "Interface name is required")
            }
            guard let privateKeyString = scratchpad[.privateKey] else {
                fieldsWithError.insert(.privateKey)
                return (false, "Interface's private key is required")
            }
            guard let privateKey = Data(base64Encoded: privateKeyString), privateKey.count == 32 else {
                fieldsWithError.insert(.privateKey)
                return(false, "Interface's private key should be a 32-byte key in base64 encoding")
            }
            var config = InterfaceConfiguration(name: name, privateKey: privateKey)
            if let addressesString = scratchpad[.addresses] {
                var addresses: [IPAddressRange] = []
                for addressString in addressesString.split(separator: ",") {
                    let trimmedString = addressString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if let address = IPAddressRange(from: trimmedString) {
                        addresses.append(address)
                    } else {
                        fieldsWithError.insert(.addresses)
                        setErrorMessage("Interface addresses should be a list of comma-separated IP addresses in CIDR notation")
                    }
                }
                config.addresses = addresses
            }
            if let listenPortString = scratchpad[.listenPort] {
                if let listenPort = UInt64(listenPortString) {
                    config.listenPort = listenPort
                } else {
                    fieldsWithError.insert(.listenPort)
                    setErrorMessage("Interface's listen port should be a number")
                }
            }
            if let mtuString = scratchpad[.mtu] {
                if let mtu = UInt64(mtuString) {
                    config.mtu = mtu
                } else {
                    fieldsWithError.insert(.mtu)
                    setErrorMessage("Interface's MTU should be a number")
                }
            }
            // TODO: Validate DNS
            if let dnsString = scratchpad[.dns] {
                config.dns = dnsString
            }

            if let firstErrorMessage = firstErrorMessage {
                return (false, firstErrorMessage)
            }
            validatedConfiguration = config
            return (true, "")
        }
    }

    class PeerData {
        var index: Int
        var scratchpad: [PeerEditField: String] = [:]
        var fieldsWithError: Set<PeerEditField> = []
        var validatedConfiguration: PeerConfiguration? = nil
        init(index: Int) {
            self.index = index
        }
        subscript(field: PeerEditField) -> String {
            get {
                ensureScratchpadIsPrepared() // When starting to read a config, setup the scratchpad to serve as a cache
                return scratchpad[field] ?? ""
            }
            set(stringValue) {
                ensureScratchpadIsPrepared() // When starting to edit a config, setup the scratchpad
                validatedConfiguration = nil // The configuration will need to be revalidated
                if (stringValue.isEmpty) {
                    scratchpad.removeValue(forKey: field)
                } else {
                    scratchpad[field] = stringValue
                }
            }
        }
        func ensureScratchpadIsPrepared() {
            guard (scratchpad.isEmpty) else { return }
            guard let config = validatedConfiguration else { return }
            scratchpad[.publicKey] = config.publicKey.base64EncodedString()
            if let preSharedKey = config.preSharedKey {
                scratchpad[.preSharedKey] = preSharedKey.base64EncodedString()
            }
            if (!config.allowedIPs.isEmpty) {
                scratchpad[.allowedIPs] = config.allowedIPs.map { $0.stringRepresentation() }.joined(separator: ", ")
            }
            if let endpoint = config.endpoint {
                scratchpad[.endpoint] = endpoint.stringRepresentation()
            }
            if let persistentKeepAlive = config.persistentKeepAlive {
                scratchpad[.persistentKeepAlive] = String(persistentKeepAlive)
            }
        }
        func validate() -> (success: Bool, errorMessage: String) {
            var firstErrorMessage: String? = nil
            func setErrorMessage(_ errorMessage: String) {
                if (firstErrorMessage == nil) {
                    firstErrorMessage = errorMessage
                }
            }
            fieldsWithError.removeAll()
            guard let publicKeyString = scratchpad[.publicKey] else {
                fieldsWithError.insert(.publicKey)
                return (success: false, errorMessage: "Peer's public key is required")
            }
            guard let publicKey = Data(base64Encoded: publicKeyString), publicKey.count == 32 else {
                fieldsWithError.insert(.publicKey)
                return (success: false, errorMessage: "Peer's public key should be a 32-byte key in base64 encoding")
            }
            var config = PeerConfiguration(publicKey: publicKey)
            if let preSharedKeyString = scratchpad[.publicKey] {
                if let preSharedKey = Data(base64Encoded: preSharedKeyString), preSharedKey.count == 32 {
                    config.preSharedKey = preSharedKey
                } else {
                    fieldsWithError.insert(.preSharedKey)
                    setErrorMessage("Peer's pre-shared key should be a 32-byte key in base64 encoding")
                }
            }
            if let allowedIPsString = scratchpad[.allowedIPs] {
                var allowedIPs: [IPAddressRange] = []
                for allowedIPString in allowedIPsString.split(separator: ",") {
                    let trimmedString = allowedIPString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if let allowedIP = IPAddressRange(from: trimmedString) {
                        allowedIPs.append(allowedIP)
                    } else {
                        fieldsWithError.insert(.allowedIPs)
                        setErrorMessage("Peer's allowedIPs should be a list of comma-separated IP addresses in CIDR notation")
                    }
                }
                config.allowedIPs = allowedIPs
            }
            if let endpointString = scratchpad[.endpoint] {
                if let endpoint = Endpoint(from: endpointString) {
                    config.endpoint = endpoint
                } else {
                    fieldsWithError.insert(.endpoint)
                    setErrorMessage("Peer's endpoint should be of the form 'host:port' or '[host]:port'")
                }
            }
            if let persistentKeepAliveString = scratchpad[.persistentKeepAlive] {
                if let persistentKeepAlive = UInt64(persistentKeepAliveString) {
                    config.persistentKeepAlive = persistentKeepAlive
                } else {
                    fieldsWithError.insert(.persistentKeepAlive)
                    setErrorMessage("Peer's persistent keepalive should be a number")
                }
            }

            if let firstErrorMessage = firstErrorMessage {
                return (false, firstErrorMessage)
            }
            validatedConfiguration = config
            scratchpad = [:]
            return (true, "")
        }
    }

    var interfaceData: InterfaceData
    var peersData: [PeerData]

    // MARK: TunnelEditTableViewController methods

    init() {
        interfaceData = InterfaceData()
        peersData = []
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
        print("Save")
    }

    @objc func cancelTapped() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: UITableViewDataSource

extension TunnelEditTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        let numberOfInterfaceSections = interfaceEditFieldsBySection.count
        let numberOfPeerSections = peerEditFieldsBySection.count
        let numberOfPeers = peersData.count

        return numberOfInterfaceSections + (numberOfPeers * numberOfPeerSections) + 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numberOfInterfaceSections = interfaceEditFieldsBySection.count
        let numberOfPeerSections = peerEditFieldsBySection.count
        let numberOfPeers = peersData.count

        if (section < numberOfInterfaceSections) {
            // Interface
            return interfaceEditFieldsBySection[section].count
        } else if ((numberOfPeers > 0) && (section < (numberOfInterfaceSections + numberOfPeers * numberOfPeerSections))) {
            // Peer
            let fieldIndex = (section - numberOfInterfaceSections) % numberOfPeerSections
            return peerEditFieldsBySection[fieldIndex].count
        } else {
            // Add peer
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let numberOfInterfaceSections = interfaceEditFieldsBySection.count
        let numberOfPeerSections = peerEditFieldsBySection.count
        let numberOfPeers = peersData.count

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
        let numberOfInterfaceSections = interfaceEditFieldsBySection.count
        let numberOfPeerSections = peerEditFieldsBySection.count
        let numberOfPeers = peersData.count

        let section = indexPath.section
        let row = indexPath.row

        if (section < numberOfInterfaceSections) {
            // Interface
            let field = interfaceEditFieldsBySection[section][row]
            if (field == .generateKeyPair) {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelsEditTableViewButtonCell.id, for: indexPath) as! TunnelsEditTableViewButtonCell
                cell.buttonText = field.rawValue
                cell.onTapped = {
                    print("Generating keypair is unimplemented") // TODO
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelsEditTableViewKeyValueCell.id, for: indexPath) as! TunnelsEditTableViewKeyValueCell
                cell.key = field.rawValue
                switch (field) {
                case .name:
                    cell.placeholderText = "Required"
                    cell.value = interfaceData[.name]
                    cell.onValueChanged = { [weak interfaceData] value in
                        interfaceData?[.name] = value
                    }
                case .privateKey:
                    cell.placeholderText = "Required"
                    cell.value = interfaceData[.privateKey]
                    cell.onValueChanged = { [weak interfaceData] value in
                        interfaceData?[.privateKey] = value
                    }
                case .publicKey:
                    cell.isValueEditable = false
                    cell.value = "Unimplemented"
                case .generateKeyPair:
                    break
                case .addresses:
                    cell.value = interfaceData[.addresses]
                    cell.onValueChanged = { [weak interfaceData] value in
                        interfaceData?[.addresses] = value
                    }
                    break
                case .listenPort:
                    cell.value = interfaceData[.listenPort]
                    cell.onValueChanged = { [weak interfaceData] value in
                        interfaceData?[.listenPort] = value
                    }
                    break
                case .mtu:
                    cell.placeholderText = "Automatic"
                    cell.value = interfaceData[.mtu]
                    cell.onValueChanged = { [weak interfaceData] value in
                        interfaceData?[.mtu] = value
                    }
                case .dns:
                    cell.value = interfaceData[.dns]
                    cell.onValueChanged = { [weak interfaceData] value in
                        interfaceData?[.dns] = value
                    }
                    break
                }
                return cell
            }
        } else if ((numberOfPeers > 0) && (section < (numberOfInterfaceSections + numberOfPeers * numberOfPeerSections))) {
            // Peer
            let peerIndex = Int((section - numberOfInterfaceSections) / numberOfPeerSections)
            let peerSectionIndex = (section - numberOfInterfaceSections) % numberOfPeerSections
            let peerData = peersData[peerIndex]
            let field = peerEditFieldsBySection[peerSectionIndex][row]
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
                cell.key = field.rawValue
                switch (field) {
                case .publicKey:
                    cell.placeholderText = "Required"
                    cell.value = peerData[.publicKey]
                    cell.onValueChanged = { [weak peerData] value in
                        peerData?[.publicKey] = value
                    }
                case .preSharedKey:
                    cell.value = peerData[.preSharedKey]
                    cell.onValueChanged = { [weak peerData] value in
                        peerData?[.preSharedKey] = value
                    }
                    break
                case .endpoint:
                    cell.value = peerData[.endpoint]
                    cell.onValueChanged = { [weak peerData] value in
                        peerData?[.endpoint] = value
                    }
                    break
                case .persistentKeepAlive:
                    cell.value = peerData[.persistentKeepAlive]
                    cell.onValueChanged = { [weak peerData] value in
                        peerData?[.persistentKeepAlive] = value
                    }
                    break
                case .allowedIPs:
                    cell.value = peerData[.allowedIPs]
                    cell.onValueChanged = { [weak peerData] value in
                        peerData?[.allowedIPs] = value
                    }
                    break
                case .excludePrivateIPs:
                    break
                case .deletePeer:
                    break
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
        let numberOfInterfaceSections = interfaceEditFieldsBySection.count
        let numberOfPeerSections = peerEditFieldsBySection.count
        let numberOfPeers = peersData.count

        let peer = PeerData(index: peersData.count)
        peersData.append(peer)

        let firstAddedSectionIndex = (numberOfInterfaceSections + numberOfPeers * numberOfPeerSections)
        let addedSectionIndices = IndexSet(integersIn: firstAddedSectionIndex ..< firstAddedSectionIndex + numberOfPeerSections)
        return addedSectionIndices
    }

    func deletePeer(peer: PeerData) -> IndexSet {
        let numberOfInterfaceSections = interfaceEditFieldsBySection.count
        let numberOfPeerSections = peerEditFieldsBySection.count
        let numberOfPeers = peersData.count

        assert(peer.index < numberOfPeers)

        let removedPeer = peersData.remove(at: peer.index)
        assert(removedPeer.index == peer.index)
        for p in peersData[peer.index ..< peersData.count] {
            assert(p.index > 0)
            p.index = p.index - 1
        }

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
