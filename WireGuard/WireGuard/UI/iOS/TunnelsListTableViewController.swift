// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import UIKit

class TunnelsListTableViewController: UITableViewController {

    var tunnelsManager: TunnelsManager? = nil
    var onTunnelsManagerReady: ((TunnelsManager) -> Void)? = nil

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
                s.onTunnelsManagerReady?(tunnelsManager)
                s.onTunnelsManagerReady = nil
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
                    s.presentViewControllerForTunnelCreation(tunnelsManager: tunnelsManager, tunnelConfiguration: nil)
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

    func openForEditing(configFileURL: URL) {
        let tunnelConfiguration: TunnelConfiguration?
        let name = configFileURL.deletingPathExtension().lastPathComponent
        do {
            let fileContents = try String(contentsOf: configFileURL)
            try tunnelConfiguration = WgQuickConfigFileParser.parse(fileContents)
        } catch {
            showErrorAlert(title: "Could not import config", message: "There was an error importing the config file")
            return
        }
        tunnelConfiguration?.interface.name = name
        if let tunnelsManager = tunnelsManager {
            presentViewControllerForTunnelCreation(tunnelsManager: tunnelsManager, tunnelConfiguration: tunnelConfiguration)
        } else {
            onTunnelsManagerReady = { [weak self] tunnelsManager in
                self?.presentViewControllerForTunnelCreation(tunnelsManager: tunnelsManager, tunnelConfiguration: tunnelConfiguration)
            }
        }
    }

    func presentViewControllerForTunnelCreation(tunnelsManager: TunnelsManager, tunnelConfiguration: TunnelConfiguration?) {
        let editVC = TunnelEditTableViewController(tunnelsManager: tunnelsManager, tunnelConfiguration: tunnelConfiguration)
        editVC.delegate = self
        let editNC = UINavigationController(rootViewController: editVC)
        editNC.modalPresentationStyle = .formSheet
        self.present(editNC, animated: true)
    }

    func showErrorAlert(title: String, message: String) {
        let okAction = UIAlertAction(title: "Ok", style: .default)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)

        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: TunnelEditTableViewControllerDelegate

extension TunnelsListTableViewController: TunnelEditTableViewControllerDelegate {
    func tunnelSaved(tunnel: TunnelContainer) {
        guard let tunnelsManager = tunnelsManager else { return }
        let tunnelDetailVC = TunnelDetailTableViewController(tunnelsManager: tunnelsManager,
                                                             tunnel: tunnel)
        let tunnelDetailNC = UINavigationController(rootViewController: tunnelDetailVC)
        showDetailViewController(tunnelDetailNC, sender: self) // Shall get propagated up to the split-vc
    }
    func tunnelEditingCancelled() {
        // Nothing to do here
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
        let tunnel = tunnelsManager.tunnel(at: indexPath.row)
        let tunnelDetailVC = TunnelDetailTableViewController(tunnelsManager: tunnelsManager,
                                                             tunnel: tunnel)
        let tunnelDetailNC = UINavigationController(rootViewController: tunnelDetailVC)
        showDetailViewController(tunnelDetailNC, sender: self) // Shall get propagated up to the split-vc
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
