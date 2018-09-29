//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import UIKit
import CoreData
import NetworkExtension

import BNRCoreDataStack
import PromiseKit

protocol TunnelInfoTableViewControllerDelegate: class {
    func connect(tunnel: Tunnel, tunnelInfoTableViewController: TunnelInfoTableViewController)
    func disconnect(tunnel: Tunnel, tunnelInfoTableViewController: TunnelInfoTableViewController)
    func configure(tunnel: Tunnel, tunnelInfoTableViewController: TunnelInfoTableViewController)
    func showSettings()
    func status(for tunnel: Tunnel, tunnelInfoTableViewController: TunnelInfoTableViewController) -> NEVPNStatus
}

class TunnelInfoTableViewController: UITableViewController {

    @IBOutlet weak var editButton: UIBarButtonItem!

    private var viewContext: NSManagedObjectContext!
    private weak var delegate: TunnelInfoTableViewControllerDelegate?
    private var tunnel: Tunnel!

    func configure(context: NSManagedObjectContext, delegate: TunnelInfoTableViewControllerDelegate? = nil, tunnel: Tunnel) {
        viewContext = context
        self.delegate = delegate
        self.tunnel = tunnel
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Get rid of seperator lines in table.
        tableView.tableFooterView = UIView(frame: CGRect.zero)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(VPNStatusDidChange(notification:)),
                                               name: .NEVPNStatusDidChange,
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)

        self.tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 1:
            return tunnel?.peers?.count ?? 0
        default:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(type: InterfaceInfoTableViewCell.self, for: indexPath)
            cell.delegate = self
            cell.configure(model: tunnel.interface, status: delegate?.status(for: tunnel, tunnelInfoTableViewController: self) ?? .invalid)
            return cell
        default:
            let cell =  tableView.dequeueReusableCell(type: PeerInfoTableViewCell.self, for: indexPath)
            if let peer = tunnel.peers?.object(at: indexPath.row) as? Peer {
                cell.peer = peer
            } else {
                let peer = Peer(context: tunnel.managedObjectContext!)
                tunnel.addToPeers(peer)
                cell.peer = peer
            }
            return cell
        }
    }

    @IBAction func showSettings(_ sender: Any) {
        delegate?.showSettings()
    }

    @IBAction func editTunnelConfiguration(_ sender: Any) {
        delegate?.configure(tunnel: self.tunnel, tunnelInfoTableViewController: self)
    }

    @objc private func VPNStatusDidChange(notification: NSNotification) {
        guard let session = notification.object as? NETunnelProviderSession else {
            return
        }

        guard let prot = session.manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return
        }

        guard let changedTunnelIdentifier = prot.providerConfiguration?[PCKeys.tunnelIdentifier.rawValue] as? String else {
            return
        }

        guard tunnel.tunnelIdentifier == changedTunnelIdentifier else {
            return
        }

        self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
    }
}

extension TunnelInfoTableViewController: InterfaceInfoTableViewCellDelegate {
    func connect(tunnelIdentifier: String) {
        delegate?.connect(tunnel: tunnel, tunnelInfoTableViewController: self)
    }

    func disconnect(tunnelIdentifier: String) {
        delegate?.disconnect(tunnel: tunnel, tunnelInfoTableViewController: self)
    }
}

protocol InterfaceInfoTableViewCellDelegate: class {
    func connect(tunnelIdentifier: String)
    func disconnect(tunnelIdentifier: String)
}

class InterfaceInfoTableViewCell: UITableViewCell {
    weak var delegate: InterfaceInfoTableViewCellDelegate?
    private var model: Interface! {
        didSet {
            nameField.text = model.tunnel?.title
            addressesField.text = model.addresses
            publicKeyField.text = model.publicKey
        }
    }

    func configure(model: Interface!, status: NEVPNStatus) {
        self.model = model

        if status == .connecting || status == .disconnecting || status == .reasserting {
            activityIndicator.startAnimating()
            tunnelSwitch.isHidden = true
        } else {
            activityIndicator.stopAnimating()
            tunnelSwitch.isHidden = false
        }

        tunnelSwitch.isOn = status == .connected
        tunnelSwitch.onTintColor = status == .invalid || status == .reasserting ? .gray : .green
        tunnelSwitch.isEnabled = true
    }

    @IBAction func tunnelSwitchChanged(_ sender: Any) {
        tunnelSwitch.isEnabled = false

        guard let tunnelIdentifier = model.tunnel?.tunnelIdentifier else {
            return
        }

        if tunnelSwitch.isOn {
            delegate?.connect(tunnelIdentifier: tunnelIdentifier)
        } else {
            delegate?.disconnect(tunnelIdentifier: tunnelIdentifier)
        }
    }

    @IBOutlet weak var nameField: UILabel!
    @IBOutlet weak var addressesField: UILabel!
    @IBOutlet weak var publicKeyField: UILabel!
    @IBOutlet weak var tunnelSwitch: UISwitch!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    @IBAction func copyPublicKey(_ sender: Any) {
        if let publicKey = model.publicKey {
            UIPasteboard.general.string = publicKey
        }
    }
}

class PeerInfoTableViewCell: UITableViewCell {
    var peer: Peer! {
        didSet {
            publicKeyField.text = peer.publicKey
            allowedIpsField.text = peer.allowedIPs
            endpointField.text = peer.endpoint
        }
    }

    @IBOutlet weak var publicKeyField: UILabel!
    @IBOutlet weak var allowedIpsField: UILabel!
    @IBOutlet weak var endpointField: UILabel!

    @IBAction func copyPublicKey(_ sender: Any) {
        if let publicKey = peer.publicKey {
            UIPasteboard.general.string = publicKey
        }
    }
}

extension TunnelInfoTableViewController: Identifyable {}
extension InterfaceInfoTableViewCell: Identifyable {}
extension PeerInfoTableViewCell: Identifyable {}
