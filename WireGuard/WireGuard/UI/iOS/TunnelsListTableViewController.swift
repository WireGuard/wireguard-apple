// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import UIKit
import MobileCoreServices

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

        self.tableView.rowHeight = 60

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
        let importFileAction = UIAlertAction(title: "Import file or archive", style: .default) { [weak self] (action) in
            self?.presentViewControllerForFileImport()
        }
        alert.addAction(importFileAction)

        let scanQRCodeAction = UIAlertAction(title: "Scan QR code", style: .default) { [weak self] (action) in
            self?.presentViewControllerForScanningQRCode()
        }
        alert.addAction(scanQRCodeAction)

        let createFromScratchAction = UIAlertAction(title: "Create from scratch", style: .default) { [weak self] (action) in
            if let s = self, let tunnelsManager = s.tunnelsManager {
                s.presentViewControllerForTunnelCreation(tunnelsManager: tunnelsManager, tunnelConfiguration: nil)
            }
        }
        alert.addAction(createFromScratchAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)

        // popoverPresentationController will be nil on iPhone and non-nil on iPad
        alert.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        self.present(alert, animated: true, completion: nil)
    }

    func openForEditing(configFileURL: URL) {
        let tunnelConfiguration: TunnelConfiguration?
        let name = configFileURL.deletingPathExtension().lastPathComponent
        do {
            let fileContents = try String(contentsOf: configFileURL)
            try tunnelConfiguration = WgQuickConfigFileParser.parse(fileContents, name: name)
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

    func presentViewControllerForFileImport() {
        let documentTypes = ["com.wireguard.config.quick", String(kUTTypeZipArchive)]
        let filePicker = UIDocumentPickerViewController(documentTypes: documentTypes, in: .import)
        filePicker.delegate = self
        self.present(filePicker, animated: true)
    }

    func presentViewControllerForScanningQRCode() {
        let scanQRCodeVC = QRScanViewController()
        scanQRCodeVC.delegate = self
        let scanQRCodeNC = UINavigationController(rootViewController: scanQRCodeVC)
        scanQRCodeNC.modalPresentationStyle = .fullScreen
        self.present(scanQRCodeNC, animated: true)
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

// MARK: UIDocumentPickerDelegate

extension TunnelsListTableViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            if (url.pathExtension == "conf") {
                openForEditing(configFileURL: url)
            } else if (url.pathExtension == "zip") {
                var unarchivedFiles: [(fileName: String, contents: Data)] = []
                do {
                    unarchivedFiles = try ZipArchive.unarchive(url: url, requiredFileExtensions: ["conf"])
                } catch ZipArchiveError.cantOpenInputZipFile {
                    showErrorAlert(title: "Cannot read zip archive", message: "The zip file couldn't be read")
                } catch ZipArchiveError.badArchive {
                    showErrorAlert(title: "Cannot read zip archive", message: "Bad archive")
                } catch (let error) {
                    print("Error opening zip archive: \(error)")
                }
                for unarchivedFile in unarchivedFiles {
                    if let fileBaseName = URL(string: unarchivedFile.fileName)?.deletingPathExtension().lastPathComponent,
                        let fileContents = String(data: unarchivedFile.contents, encoding: .utf8),
                        let tunnelConfiguration = try? WgQuickConfigFileParser.parse(fileContents, name: fileBaseName) {
                        tunnelsManager?.add(tunnelConfiguration: tunnelConfiguration) { (tunnel, error) in
                            if (error != nil) {
                                print("Error adding configuration: \(tunnelConfiguration.interface.name)")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: QRScanViewControllerDelegate

extension TunnelsListTableViewController: QRScanViewControllerDelegate {
    func scannedQRCode(tunnelConfiguration: TunnelConfiguration, qrScanViewController: QRScanViewController) {
        tunnelsManager?.add(tunnelConfiguration: tunnelConfiguration) { [weak self] (tunnel, error) in
            if let error = error {
                print("Could not add tunnel: \(error)")
                self?.showErrorAlert(title: "Could not save scanned config", message: "Internal error")
            }
        }
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
            cell.tunnel = tunnel
            cell.onSwitchToggled = { [weak self] isOn in
                guard let s = self, let tunnelsManager = s.tunnelsManager else { return }
                if (isOn) {
                    tunnelsManager.startActivation(of: tunnel) { error in
                        print("Error while activating: \(String(describing: error))")
                    }
                } else {
                    tunnelsManager.startDeactivation(of: tunnel) { error in
                        print("Error while deactivating: \(String(describing: error))")
                    }
                }
            }
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
    func tunnelAdded(at index: Int) {
        tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
    }

    func tunnelModified(at index: Int) {
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
    }

    func tunnelsChanged() {
        tableView.reloadData()
    }
}

class TunnelsListTableViewCell: UITableViewCell {
    static let id: String = "TunnelsListTableViewCell"
    var tunnel: TunnelContainer? {
        didSet(value) {
            // Bind to the tunnel's name
            nameLabel.text = tunnel?.name ?? ""
            nameObservervationToken = tunnel?.observe(\.name) { [weak self] (tunnel, _) in
                self?.nameLabel.text = tunnel.name
            }
            // Bind to the tunnel's status
            update(from: tunnel?.status)
            statusObservervationToken = tunnel?.observe(\.status) { [weak self] (tunnel, _) in
                self?.update(from: tunnel.status)
            }
        }
    }
    var onSwitchToggled: ((Bool) -> Void)? = nil

    let nameLabel: UILabel
    let busyIndicator: UIActivityIndicatorView
    let statusSwitch: UISwitch

    private var statusObservervationToken: AnyObject? = nil
    private var nameObservervationToken: AnyObject? = nil

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        nameLabel = UILabel()
        busyIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        busyIndicator.hidesWhenStopped = true
        statusSwitch = UISwitch()
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(statusSwitch)
        statusSwitch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusSwitch.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -8)
            ])
        contentView.addSubview(busyIndicator)
        busyIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            busyIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            busyIndicator.rightAnchor.constraint(equalTo: statusSwitch.leftAnchor, constant: -8)
            ])
        contentView.addSubview(nameLabel)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 16),
            nameLabel.rightAnchor.constraint(equalTo: busyIndicator.leftAnchor)
            ])
        self.accessoryType = .disclosureIndicator

        statusSwitch.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
    }

    @objc func switchToggled() {
        onSwitchToggled?(statusSwitch.isOn)
    }

    private func update(from status: TunnelStatus?) {
        guard let status = status else {
            reset()
            return
        }
        DispatchQueue.main.async { [weak statusSwitch, weak busyIndicator] in
            guard let statusSwitch = statusSwitch, let busyIndicator = busyIndicator else { return }
            statusSwitch.isOn = !(status == .deactivating || status == .inactive)
            statusSwitch.isUserInteractionEnabled = (status == .inactive || status == .active)
            if (status == .inactive || status == .active) {
                busyIndicator.stopAnimating()
            } else {
                busyIndicator.startAnimating()
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func reset() {
        statusSwitch.isOn = false
        statusSwitch.isUserInteractionEnabled = false
        busyIndicator.stopAnimating()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        reset()
    }
}
