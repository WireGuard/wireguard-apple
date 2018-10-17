//
//  TunnelsListTableViewController.swift
//  WireGuard
//
//  Created by Roopesh Chander on 12/10/18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import UIKit

class TunnelsListTableViewController: UITableViewController {

    var tunnelsManager: TunnelsManager? = nil

    init() {
        super.init(style: .plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "WireGuard"
        let addButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonTapped(sender:)))
        self.navigationItem.rightBarButtonItem = addButtonItem

        self.tableView.register(TunnelsListTableViewCell.self, forCellReuseIdentifier: TunnelsListTableViewCell.id)

        TunnelsManager.create { [weak self] tunnelsManager in
            guard let tunnelsManager = tunnelsManager else { return }
            self?.tunnelsManager = tunnelsManager
            self?.tableView.reloadData()
        }
    }

    @objc func addButtonTapped(sender: UIBarButtonItem!) {
        print("Add button tapped")
    }
}

// MARK: UITableViewDataSource

extension TunnelsListTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (tunnelsManager?.numberOfTunnels() ?? 0)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TunnelsListTableViewCell.id, for: indexPath) as! TunnelsListTableViewCell
        if let tunnelsManager = tunnelsManager {
            let tunnel = tunnelsManager.tunnel(at: indexPath.row)
            cell.tunnelName = tunnel.name
        }
        return cell
    }
}

class TunnelsListTableViewCell: UITableViewCell {
    static let id: String = "TunnelsListTableViewCell"
    var tunnelName: String {
        get { return textLabel?.text ?? "" }
        set(value) { textLabel?.text = value }
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.accessoryType = .disclosureIndicator
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
