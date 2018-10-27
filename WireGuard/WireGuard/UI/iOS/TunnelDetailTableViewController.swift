// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import UIKit

// MARK: TunnelDetailTableViewController

class TunnelDetailTableViewController: UITableViewController {

    let interfaceFieldsBySection: [[TunnelViewModel.InterfaceField]] = [
        [.name],
        [.publicKey, .copyPublicKey],
        [.addresses, .listenPort, .mtu, .dns]
    ]

    let peerFieldsBySection: [[TunnelViewModel.PeerField]] = [
        [.publicKey, .preSharedKey, .endpoint,
         .allowedIPs, .persistentKeepAlive]
    ]

    let tunnelsManager: TunnelsManager
    let tunnel: TunnelContainer
    var tunnelViewModel: TunnelViewModel

    init(tunnelsManager tm: TunnelsManager, tunnel t: TunnelContainer) {
        tunnelsManager = tm
        tunnel = t
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: t.tunnelConfiguration())
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = tunnelViewModel.interfaceData[.name]
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editTapped))

        self.tableView.rowHeight = 44
        self.tableView.register(TunnelDetailTableViewStatusCell.self, forCellReuseIdentifier: TunnelDetailTableViewStatusCell.id)
        self.tableView.register(TunnelDetailTableViewKeyValueCell.self, forCellReuseIdentifier: TunnelDetailTableViewKeyValueCell.id)
        self.tableView.register(TunnelDetailTableViewButtonCell.self, forCellReuseIdentifier: TunnelDetailTableViewButtonCell.id)
    }

    @objc func editTapped() {
        let editVC = TunnelEditTableViewController(tunnelsManager: tunnelsManager, tunnel: tunnel)
        editVC.delegate = self
        let editNC = UINavigationController(rootViewController: editVC)
        editNC.modalPresentationStyle = .formSheet
        present(editNC, animated: true)
    }

    func showErrorAlert(title: String, message: String) {
        let okAction = UIAlertAction(title: "Ok", style: .default)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)

        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: TunnelEditTableViewControllerDelegate

extension TunnelDetailTableViewController: TunnelEditTableViewControllerDelegate {
    func tunnelSaved(tunnel: TunnelContainer) {
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration())
        self.tableView.reloadData()
    }
    func tunnelEditingCancelled() {
        // Nothing to do
    }
}

// MARK: UITableViewDataSource

extension TunnelDetailTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        let interfaceData = tunnelViewModel.interfaceData
        let numberOfInterfaceSections = (0 ..< interfaceFieldsBySection.count).filter { section in
            (!interfaceData.filterFieldsWithValueOrControl(interfaceFields: interfaceFieldsBySection[section]).isEmpty)
        }.count
        let numberOfPeerSections = peerFieldsBySection.count
        let numberOfPeers = tunnelViewModel.peersData.count

        return 1 + numberOfInterfaceSections + (numberOfPeers * numberOfPeerSections) + 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let interfaceData = tunnelViewModel.interfaceData
        let numberOfInterfaceSections = (0 ..< interfaceFieldsBySection.count).filter { section in
            (!interfaceData.filterFieldsWithValueOrControl(interfaceFields: interfaceFieldsBySection[section]).isEmpty)
            }.count
        let numberOfPeerSections = peerFieldsBySection.count
        let numberOfPeers = tunnelViewModel.peersData.count

        if (section == 0) {
            // Status
            return 1
        } else if (section < (1 + numberOfInterfaceSections)) {
            // Interface
            return interfaceData.filterFieldsWithValueOrControl(interfaceFields: interfaceFieldsBySection[section - 1]).count
        } else if ((numberOfPeers > 0) && (section < (1 + numberOfInterfaceSections + numberOfPeers * numberOfPeerSections))) {
            // Peer
            let peerIndex = Int((section - 1 - numberOfInterfaceSections) / numberOfPeerSections)
            let peerData = tunnelViewModel.peersData[peerIndex]
            let peerSectionIndex = (section - 1 - numberOfInterfaceSections) % numberOfPeerSections
            return peerData.filterFieldsWithValueOrControl(peerFields: peerFieldsBySection[peerSectionIndex]).count
        } else {
            // Delete tunnel
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let interfaceData = tunnelViewModel.interfaceData
        let numberOfInterfaceSections = (0 ..< interfaceFieldsBySection.count).filter { section in
            (!interfaceData.filterFieldsWithValueOrControl(interfaceFields: interfaceFieldsBySection[section]).isEmpty)
            }.count
        let numberOfPeerSections = peerFieldsBySection.count
        let numberOfPeers = tunnelViewModel.peersData.count

        if (section == 0) {
            // Status
            return "Status"
        } else if (section < 1 + numberOfInterfaceSections) {
            // Interface
            return (section == 1) ? "Interface" : nil
        } else if ((numberOfPeers > 0) && (section < (1 + numberOfInterfaceSections + numberOfPeers * numberOfPeerSections))) {
            // Peer
            let peerSectionIndex = (section - 1 - numberOfInterfaceSections) % numberOfPeerSections
            return (peerSectionIndex == 0) ? "Peer" : nil
        } else {
            // Add peer
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let interfaceData = tunnelViewModel.interfaceData
        let numberOfInterfaceSections = (0 ..< interfaceFieldsBySection.count).filter { section in
            (!interfaceData.filterFieldsWithValueOrControl(interfaceFields: interfaceFieldsBySection[section]).isEmpty)
            }.count
        let numberOfPeerSections = peerFieldsBySection.count
        let numberOfPeers = tunnelViewModel.peersData.count

        let section = indexPath.section
        let row = indexPath.row

        if (section == 0) {
            // Status
            let cell = tableView.dequeueReusableCell(withIdentifier: TunnelDetailTableViewStatusCell.id, for: indexPath) as! TunnelDetailTableViewStatusCell
            cell.tunnel = self.tunnel
            cell.onSwitchToggled = { [weak self] isOn in
                cell.isSwitchInteractionEnabled = false
                guard let s = self else { return }
                if (isOn) {
                    s.tunnelsManager.startActivation(of: s.tunnel) { error in
                        print("Error while activating: \(String(describing: error))")
                    }
                } else {
                    s.tunnelsManager.startDeactivation(of: s.tunnel) { error in
                        print("Error while deactivating: \(String(describing: error))")
                    }
                }
            }
            return cell
        } else if (section < 1 + numberOfInterfaceSections) {
            // Interface
            let field = interfaceData.filterFieldsWithValueOrControl(interfaceFields: interfaceFieldsBySection[section - 1])[row]
            if (field == .copyPublicKey) {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelDetailTableViewButtonCell.id, for: indexPath) as! TunnelDetailTableViewButtonCell
                cell.buttonText = field.rawValue
                cell.onTapped = {
                    print("Copying public key is unimplemented") // TODO
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: TunnelDetailTableViewKeyValueCell.id, for: indexPath) as! TunnelDetailTableViewKeyValueCell
                // Set key and value
                cell.key = field.rawValue
                cell.value = interfaceData[field]
                if (field != .publicKey) {
                    cell.detailTextLabel?.allowsDefaultTighteningForTruncation = true
                    cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
                    cell.detailTextLabel?.minimumScaleFactor = 0.85
                }
                return cell
            }
        } else if ((numberOfPeers > 0) && (section < (1 + numberOfInterfaceSections + numberOfPeers * numberOfPeerSections))) {
            // Peer
            let peerIndex = Int((section - 1 - numberOfInterfaceSections) / numberOfPeerSections)
            let peerSectionIndex = (section - 1 - numberOfInterfaceSections) % numberOfPeerSections
            let peerData = tunnelViewModel.peersData[peerIndex]
            let field = peerData.filterFieldsWithValueOrControl(peerFields: peerFieldsBySection[peerSectionIndex])[row]

            let cell = tableView.dequeueReusableCell(withIdentifier: TunnelDetailTableViewKeyValueCell.id, for: indexPath) as! TunnelDetailTableViewKeyValueCell
            // Set key and value
            cell.key = field.rawValue
            cell.value = peerData[field]
            if (field != .publicKey && field != .preSharedKey) {
                cell.detailTextLabel?.allowsDefaultTighteningForTruncation = true
                cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
                cell.detailTextLabel?.minimumScaleFactor = 0.85
            }

            return cell
        } else {
            assert(section == (1 + numberOfInterfaceSections + numberOfPeers * numberOfPeerSections))
            // Delete configuration
            let cell = tableView.dequeueReusableCell(withIdentifier: TunnelDetailTableViewButtonCell.id, for: indexPath) as! TunnelDetailTableViewButtonCell
            cell.buttonText = "Delete tunnel"
            cell.onTapped = {
                print("Delete peer unimplemented")
            }
            return cell
        }
    }
}

class TunnelDetailTableViewStatusCell: UITableViewCell {
    static let id: String = "TunnelDetailTableViewStatusCell"

    var tunnel: TunnelContainer? {
        didSet(value) {
            update(from: tunnel?.status)
            statusObservervationToken = tunnel?.observe(\.status) { [weak self] (tunnel, _) in
                self?.update(from: tunnel.status)
            }
        }
    }
    var isSwitchInteractionEnabled: Bool {
        get { return statusSwitch.isUserInteractionEnabled }
        set(value) { statusSwitch.isUserInteractionEnabled = value }
    }
    var onSwitchToggled: ((Bool) -> Void)? = nil
    private var isOnSwitchToggledHandlerEnabled: Bool = true

    let statusSwitch: UISwitch
    private var statusObservervationToken: AnyObject? = nil

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        statusSwitch = UISwitch()
        super.init(style: .default, reuseIdentifier: TunnelDetailTableViewKeyValueCell.id)
        accessoryView = statusSwitch

        statusSwitch.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
    }

    @objc func switchToggled() {
        if (isOnSwitchToggledHandlerEnabled) {
            onSwitchToggled?(statusSwitch.isOn)
        }
    }

    private func update(from status: TunnelStatus?) {
        guard let status = status else {
            reset()
            return
        }
        let text: String
        switch (status) {
        case .inactive:
            text = "Inactive"
        case .activating:
            text = "Activating"
        case .active:
            text = "Active"
        case .deactivating:
            text = "Deactivating"
        case .reasserting:
            text = "Reactivating"
        case .resolvingEndpointDomains:
            text = "Resolving domains"
        }
        textLabel?.text = text
        DispatchQueue.main.async { [weak statusSwitch] in
            guard let statusSwitch = statusSwitch else { return }
            statusSwitch.isOn = !(status == .deactivating || status == .inactive)
            statusSwitch.isUserInteractionEnabled = (status == .inactive || status == .active || status == .resolvingEndpointDomains)
        }
        textLabel?.textColor = (status == .active || status == .inactive) ? UIColor.black : UIColor.gray
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func reset() {
        textLabel?.text = "Invalid"
        statusSwitch.isOn = false
        textLabel?.textColor = UIColor.gray
        statusSwitch.isUserInteractionEnabled = false
    }

    override func prepareForReuse() {
        reset()
    }
}

class TunnelDetailTableViewKeyValueCell: UITableViewCell {
    static let id: String = "TunnelDetailTableViewKeyValueCell"
    var key: String {
        get { return textLabel?.text ?? "" }
        set(value) { textLabel?.text = value }
    }
    var value: String {
        get { return detailTextLabel?.text ?? "" }
        set(value) { detailTextLabel?.text = value }
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: TunnelDetailTableViewKeyValueCell.id)
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

class TunnelDetailTableViewButtonCell: UITableViewCell {
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
