//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import UIKit
import CoreData
import BNRCoreDataStack
import PromiseKit

protocol TunnelInfoTableViewControllerDelegate: class {
    func configure(tunnel: Tunnel, tunnelInfoTableViewController: TunnelInfoTableViewController)
    func showSettings()
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)

        self.tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 1:
            return tunnel?.peers?.count ?? 1
        default:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(type: InterfaceInfoTableViewCell.self, for: indexPath)
            cell.model = tunnel.interface
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
}

class InterfaceInfoTableViewCell: UITableViewCell {
    var model: Interface! {
        didSet {
            nameField.text = model.tunnel?.title
            addressesField.text = model.addresses
            publicKeyField.text = model.publicKey
        }
    }

    @IBOutlet weak var nameField: UILabel!
    @IBOutlet weak var addressesField: UILabel!
    @IBOutlet weak var publicKeyField: UILabel!

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
