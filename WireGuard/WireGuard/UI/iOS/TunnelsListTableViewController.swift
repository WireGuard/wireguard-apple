//
//  TunnelsListTableViewController.swift
//  WireGuard
//
//  Created by Roopesh Chander on 12/10/18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import UIKit

class TunnelsListTableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "WireGuard"
        let addButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonTapped(sender:)))
        self.navigationItem.rightBarButtonItem = addButtonItem
    }

    @objc func addButtonTapped(sender: UIBarButtonItem!) {
        print("Add button tapped")
    }
}

// MARK: UITableViewDataSource

extension TunnelsListTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
}
