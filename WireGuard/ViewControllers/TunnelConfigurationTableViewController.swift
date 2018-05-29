//
//  TunnelConfigurationTableViewController.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 24-05-18.
//  Copyright © 2018 WireGuard. All rights reserved.
//

import UIKit
import CoreData
import BNRCoreDataStack
import PromiseKit

protocol TunnelConfigurationTableViewControllerDelegate: class {
    func didSave(tunnel: Tunnel, tunnelConfigurationTableViewController: TunnelConfigurationTableViewController)
}

class TunnelConfigurationTableViewController: UITableViewController {

    @IBOutlet weak var saveButton: UIBarButtonItem!

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
            tunnel.addToPeers(Peer(context: viewContext))

            let interface = Interface(context: viewContext)
            interface.addToAdresses(Address(context: viewContext))

            tunnel.interface = interface
        }
        return tunnel
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
            return cell 
        default:
            return tableView.dequeueReusableCell(type: AddPeerTableViewCell.self, for: indexPath)
        }
    }

    @IBAction func saveTunnelConfiguration(_ sender: Any) {
        Promise<Void>(resolver: { (seal) in
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
            print("Error saving: \(error)")
        }
    }
}

class InterfaceTableViewCell: UITableViewCell {
    var model: Interface!

    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var privateKeyField: UITextField!
    @IBOutlet weak var publicKeyField: UITextField!
    @IBOutlet weak var addressesField: UITextField!
    @IBOutlet weak var listenPortField: UITextField!
    @IBOutlet weak var dnsField: UITextField!
    @IBOutlet weak var mtuField: UITextField!

}

extension InterfaceTableViewCell: UITextFieldDelegate {
    @IBAction
    func textfieldDidChange(_ sender: UITextField) {
        let string = sender.text
        print(string)

        if sender == nameField {
            model.tunnel?.title = string
        } else if sender == privateKeyField {
            model.privateKey = string
        } else if sender == publicKeyField {
            model.publicKey = string
        } else if sender == addressesField {
            let address = Address(context: model.managedObjectContext!)
            address.address = string
            model.adresses = NSSet(array: [address])
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

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        print("\(string)")

        return true
    }
}

class PeerTableViewCell: UITableViewCell {
    var peer: Peer!

    @IBOutlet weak var publicKeyField: UITextField!
    @IBOutlet weak var preSharedKeyField: UITextField!
    @IBOutlet weak var allowedIpsField: UITextField!
    @IBOutlet weak var endpointField: UITextField!
    @IBOutlet weak var persistentKeepaliveField: UITextField!

}

extension PeerTableViewCell: UITextFieldDelegate {
    @IBAction
    func textfieldDidChange(_ sender: UITextField) {
        let string = sender.text
        print(string)

        if sender == publicKeyField {
            peer.publicKey = string
        } else if sender == preSharedKeyField {
            peer.presharedKey = string
        } else if sender == allowedIpsField {
            peer.allowedIPs = string
        } else if sender == endpointField {
            peer.endpoint = string
        } else if sender == persistentKeepaliveField {
            if let string = string, let persistentKeepalive = Int16(string) {
                peer.persistentKeepalive = persistentKeepalive
            }
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        print("\(string)")

        return true
    }
}

class AddPeerTableViewCell: UITableViewCell {
    var model: Interface?

    @IBAction func addPeer(_ sender: Any) {
        //TODO implement
        print("Implement add peer")
    }

}

extension TunnelConfigurationTableViewController: Identifyable {}
extension InterfaceTableViewCell: Identifyable {}
extension PeerTableViewCell: Identifyable {}
extension AddPeerTableViewCell: Identifyable {}
