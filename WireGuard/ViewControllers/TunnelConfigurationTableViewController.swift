//
//  TunnelConfigurationTableViewController.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 24-05-18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import UIKit
import CoreData
import BNRCoreDataStack
import PromiseKit

protocol TunnelConfigurationTableViewControllerDelegate: class {
    func didSave(tunnel: Tunnel, tunnelConfigurationTableViewController: TunnelConfigurationTableViewController)
    func export(tunnel: Tunnel, barButtonItem: UIBarButtonItem)
}

class TunnelConfigurationTableViewController: UITableViewController {

    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var exportButton: UIBarButtonItem!

    private var viewContext: NSManagedObjectContext!
    private weak var delegate: TunnelConfigurationTableViewControllerDelegate?
    private var tunnel: Tunnel!

    func configure(context: NSManagedObjectContext, delegate: TunnelConfigurationTableViewControllerDelegate? = nil, tunnel: Tunnel? = nil) {
        viewContext = context
        self.delegate = delegate
        self.tunnel = tunnel ?? generateNewTunnelConfig()
    }

    private func generateNewTunnelConfig() -> Tunnel {
        var tunnel: Tunnel! = nil

        viewContext.performAndWait {
            tunnel = Tunnel(context: viewContext)
            tunnel.tunnelIdentifier = UUID().uuidString
            let peer = Peer(context: viewContext)
            peer.allowedIPs = "0.0.0.0/0, ::/0"
            tunnel.addToPeers(peer)

            let interface = Interface(context: viewContext)

            tunnel.interface = interface
        }
        return tunnel
    }

    @IBAction func addPeer(_ sender: Any) {
        if let moc = tunnel.managedObjectContext {
            tableView.beginUpdates()
            let insertedAt = IndexPath(row: tunnel.peers?.count ?? 0, section: 1)
            tableView.insertRows(at: [insertedAt], with: .automatic)

            let peer = Peer(context: moc)
            peer.allowedIPs = "0.0.0.0/0, ::/0"
            tunnel.addToPeers(peer)

            tableView.endUpdates()
            tableView.scrollToRow(at: insertedAt, at: .middle, animated: true)
        }
    }

    @IBAction func exportTunnel(_ sender: UIBarButtonItem) {
        self.delegate?.export(tunnel: tunnel, barButtonItem: sender)
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
            let cell = tableView.dequeueReusableCell(type: InterfaceTableViewCell.self, for: indexPath)
            cell.model = tunnel.interface
            cell.delegate = self
            return cell
        case 1:
            let cell =  tableView.dequeueReusableCell(type: PeerTableViewCell.self, for: indexPath)
            if let peer = tunnel.peers?.object(at: indexPath.row) as? Peer {
                cell.peer = peer
            } else {
                let peer = Peer(context: tunnel.managedObjectContext!)
                tunnel.addToPeers(peer)
                cell.peer = peer
            }
            cell.delegate = self
            return cell
        default:
            let cell = tableView.dequeueReusableCell(type: AddPeerTableViewCell.self, for: indexPath)
            cell.tunnel = tunnel
            return cell
        }
    }

    @IBAction func saveTunnelConfiguration(_ sender: Any) {
        Promise<Void>(resolver: { (seal) in
            do {
                try tunnel.validate()
            } catch {
                seal.reject(error)
                return
            }

            viewContext.perform({
                self.viewContext.saveContext({ (result) in
                    switch result {
                    case .success:
                        seal.fulfill(())
                    case .failure(let error):
                        seal.reject(error)
                    }
                })
            })
        }).then { () -> Promise<Void> in
            self.delegate?.didSave(tunnel: self.tunnel, tunnelConfigurationTableViewController: self)
            return Promise.value(())
        }.catch { error in
            let alert = UIAlertController(title: "Error", message: "\(error)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension TunnelConfigurationTableViewController: PeerTableViewCellDelegate {
    func delete(peer: Peer) {
        if let moc = tunnel.managedObjectContext {
            tableView.beginUpdates()
            let deletedAt = IndexPath(row: tunnel.peers?.index(of: peer) ?? 0, section: 1)
            tableView.deleteRows(at: [deletedAt], with: .automatic)
            tunnel.removeFromPeers(peer)
            moc.delete(peer)
            tableView.endUpdates()
        }
    }
}

extension TunnelConfigurationTableViewController: InterfaceTableViewCellDelegate {
    func generateKeys() {
        if let moc = tunnel.managedObjectContext {
            moc.perform {
                var privateKey = Data(count: 32)
                privateKey.withUnsafeMutableBytes { (mutableBytes) -> Void in
                    curve25519_generate_private_key(mutableBytes)
                }

                self.tunnel.interface?.privateKey = privateKey.base64EncodedString()

                if let peers = self.tunnel.peers?.array as? [Peer] {
                    peers.forEach {
                        var publicKey = Data(count: 32)
                        privateKey.withUnsafeBytes({ (privateKeyBytes) -> Void in
                            publicKey.withUnsafeMutableBytes({ (mutableBytes) -> Void in
                                curve25519_derive_public_key(mutableBytes, privateKeyBytes)
                            })
                        })
                        $0.publicKey = publicKey.base64EncodedString()
                    }
                }
            }
        }
        self.tableView.reloadData()
    }
}

protocol InterfaceTableViewCellDelegate: class {
    func generateKeys()
}

class InterfaceTableViewCell: UITableViewCell {
    var model: Interface! {
        didSet {
            nameField.text = model.tunnel?.title
            addressesField.text = model.addresses
            privateKeyField.text = model.privateKey
            listenPortField.text = String(model.listenPort)
            dnsField.text = model.dns
            mtuField.text = String(model.mtu)
        }
    }

    weak var delegate: InterfaceTableViewCellDelegate?

    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var addressesField: UITextField!
    @IBOutlet weak var privateKeyField: UITextField!
    @IBOutlet weak var listenPortField: UITextField!
    @IBOutlet weak var dnsField: UITextField!
    @IBOutlet weak var mtuField: UITextField!

    @IBAction func generateTapped(_ sender: Any) {
        delegate?.generateKeys()
    }
}

extension InterfaceTableViewCell: UITextFieldDelegate {

    @IBAction
    func textfieldDidChange(_ sender: UITextField) {
        let string = sender.text

        if sender == nameField {
            model.tunnel?.title = string
        } else if sender == privateKeyField {
            model.privateKey = string
        } else if sender == addressesField {
            model.addresses = string
        } else if sender == listenPortField {
            if let string = string, let port = Int16(string) {
                model.listenPort = port
            }
        } else if sender == dnsField {
            model.dns = string
        } else if sender == mtuField {
            if let string = string, let mtu = Int32(string) {
                model.mtu = mtu
            }
        }
    }
}

protocol PeerTableViewCellDelegate: class {
    func delete(peer: Peer)
}

class PeerTableViewCell: UITableViewCell {
    var peer: Peer! {
        didSet {
            publicKeyField.text = peer.publicKey
            preSharedKeyField.text = peer.presharedKey
            allowedIpsField.text = peer.allowedIPs
            endpointField.text = peer.endpoint
            persistentKeepaliveField.text = String(peer.persistentKeepalive)
        }
    }
    weak var delegate: PeerTableViewCellDelegate?

    @IBOutlet weak var publicKeyField: UITextField!
    @IBOutlet weak var preSharedKeyField: UITextField!
    @IBOutlet weak var allowedIpsField: UITextField!
    @IBOutlet weak var endpointField: UITextField!
    @IBOutlet weak var persistentKeepaliveField: UITextField!

    @IBAction func deletePeer(_ sender: Any) {
        delegate?.delete(peer: peer)
    }
}

extension PeerTableViewCell: UITextFieldDelegate {
    @IBAction
    func textfieldDidChange(_ sender: UITextField) {
        let string = sender.text

        if sender == publicKeyField {
            peer.publicKey = string
        } else if sender == preSharedKeyField {
            peer.presharedKey = string
        } else if sender == allowedIpsField {
            peer.allowedIPs = string
        } else if sender == endpointField {
            peer.endpoint = string
        } else if sender == persistentKeepaliveField {
            if let string = string, let persistentKeepalive = Int32(string) {
                peer.persistentKeepalive = persistentKeepalive
            }
        }
    }
}

class AddPeerTableViewCell: UITableViewCell {
    var tunnel: Tunnel!

    @IBAction func addPeer(_ sender: Any) {
        if let moc = tunnel.managedObjectContext {
            tunnel.addToPeers(Peer(context: moc))
        }
    }
}

extension TunnelConfigurationTableViewController: Identifyable {}
extension InterfaceTableViewCell: Identifyable {}
extension PeerTableViewCell: Identifyable {}
extension AddPeerTableViewCell: Identifyable {}
