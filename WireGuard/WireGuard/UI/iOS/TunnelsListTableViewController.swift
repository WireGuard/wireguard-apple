// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

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
            if let s = self {
                tunnelsManager.delegate = s
                s.tunnelsManager = tunnelsManager
                s.tableView.reloadData()
            }
        }
    }

    @objc func addButtonTapped(sender: UIBarButtonItem!) {
        let alert = UIAlertController(title: "",
                                      message: "Add a tunnel",
                                      preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "Create from scratch", style: .default) { [weak self] (action) in
                if let s = self, let tunnelsManager = s.tunnelsManager {
                    let editVC = TunnelEditTableViewController(tunnelsManager: tunnelsManager)
                    let editNC = UINavigationController(rootViewController: editVC)
                    s.present(editNC, animated: true)
                }
            }
        )
        alert.addAction(
            UIAlertAction(title: "Cancel", style: .cancel)
        )
        // popoverPresentationController will be nil on iPhone and non-nil on iPad
        alert.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        self.present(alert, animated: true, completion: nil)
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

// MARK: UITableViewDelegate

extension TunnelsListTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let tunnelsManager = tunnelsManager else { return }
        let tunnelConfiguration = tunnelsManager.tunnel(at: indexPath.row).tunnelProvider.tunnelConfiguration
        let tunnelDetailVC = TunnelDetailTableViewController(tunnelsManager: tunnelsManager,
                                                             tunnelConfiguration: tunnelConfiguration)
        showDetailViewController(tunnelDetailVC, sender: self) // Shall get propagated up to the split-vc
    }
}

// MARK: TunnelsManagerDelegate

extension TunnelsListTableViewController: TunnelsManagerDelegate {
    func tunnelsAdded(atIndex index: Int, numberOfTunnels: Int) {
        self.tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
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
