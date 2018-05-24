//
//  ProfileConfigurationTableViewController.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 24-05-18.
//  Copyright © 2018 Wireguard. All rights reserved.
//

import UIKit
import CoreData
import BNRCoreDataStack

protocol ProfileConfigurationTableViewControllerDelegate: class {
}

class ProfileConfigurationTableViewController: UITableViewController {
    var viewContext: NSManagedObjectContext!
    weak var delegate: ProfileConfigurationTableViewControllerDelegate?

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
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

extension ProfileConfigurationTableViewController: Identifyable {}
extension InterfaceTableViewCell: Identifyable {}
extension PeerTableViewCell: Identifyable {}
extension AddPeerTableViewCell: Identifyable {}
