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

protocol TunnelConfigurationTableViewControllerDelegate: class {
}

class TunnelConfigurationTableViewController: UITableViewController {
    var viewContext: NSManagedObjectContext!
    weak var delegate: TunnelConfigurationTableViewControllerDelegate?

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 1:
            return 2
        default:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            return tableView.dequeueReusableCell(type: InterfaceTableViewCell.self, for: indexPath)
        case 1:
            return tableView.dequeueReusableCell(type: PeerTableViewCell.self, for: indexPath)
        default:
            return tableView.dequeueReusableCell(type: AddPeerTableViewCell.self, for: indexPath)
        }
    }
}

class InterfaceTableViewCell: UITableViewCell {

}

class PeerTableViewCell: UITableViewCell {

}

class AddPeerTableViewCell: UITableViewCell {

}

extension TunnelConfigurationTableViewController: Identifyable {}
extension InterfaceTableViewCell: Identifyable {}
extension PeerTableViewCell: Identifyable {}
extension AddPeerTableViewCell: Identifyable {}
