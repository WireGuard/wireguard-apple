// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

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
        let settingsButtonItem = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(settingsButtonTapped(sender:)))
        self.navigationItem.leftBarButtonItem = settingsButtonItem

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
        let alert = UIAlertController(title: "", message: "Add a new WireGuard tunnel", preferredStyle: .actionSheet)
        let importFileAction = UIAlertAction(title: "Create from file or archive", style: .default) { [weak self] (action) in
            self?.presentViewControllerForFileImport()
        }
        alert.addAction(importFileAction)

        let scanQRCodeAction = UIAlertAction(title: "Create from QR code", style: .default) { [weak self] (action) in
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

    @objc func settingsButtonTapped(sender: UIBarButtonItem!) {
        let settingsVC = SettingsTableViewController(tunnelsManager: tunnelsManager)
        let settingsNC = UINavigationController(rootViewController: settingsVC)
        settingsNC.modalPresentationStyle = .formSheet
        self.present(settingsNC, animated: true)
    }

    func openForEditing(configFileURL: URL) {
        let tunnelConfiguration: TunnelConfiguration?
        let name = configFileURL.deletingPathExtension().lastPathComponent
        do {
            let fileContents = try String(contentsOf: configFileURL)
            try tunnelConfiguration = WgQuickConfigFileParser.parse(fileContents, name: name)
        } catch (let error) {
            showErrorAlert(title: "Unable to import tunnel", message: "An error occured when importing the tunnel configuration: \(String(describing: error))")
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

    func importFromFile(url: URL) {
        // Import configurations from a .conf or a .zip file
        if (url.pathExtension == "conf") {
            let fileBaseName = url.deletingPathExtension().lastPathComponent
            if let fileContents = try? String(contentsOf: url),
                let tunnelConfiguration = try? WgQuickConfigFileParser.parse(fileContents, name: fileBaseName) {
                tunnelsManager?.add(tunnelConfiguration: tunnelConfiguration) { (tunnel, error) in
                    if let error = error {
                        ErrorPresenter.showErrorAlert(error: error, from: self)
                    }
                }
            } else {
                showErrorAlert(title: "Unable to import tunnel", message: "An error occured when importing the tunnel configuration.")
            }
        } else if (url.pathExtension == "zip") {
            var unarchivedFiles: [(fileName: String, contents: Data)] = []
            do {
                unarchivedFiles = try ZipArchive.unarchive(url: url, requiredFileExtensions: ["conf"])
            } catch ZipArchiveError.cantOpenInputZipFile {
                showErrorAlert(title: "Unable to read zip archive", message: "The zip archive could not be read")
            } catch ZipArchiveError.badArchive {
                showErrorAlert(title: "Unable to read zip archive", message: "Bad or corrupt zip archive")
            } catch (let error) {
                showErrorAlert(title: "Unable to read zip archive", message: "Unexpected error: \(String(describing: error))")
            }
            var numberOfConfigFilesWithErrors = 0
            var tunnelConfigurationsToAdd: [TunnelConfiguration] = []
            for unarchivedFile in unarchivedFiles {
                guard let tunnelsManager = tunnelsManager else { return }
                if let fileBaseName = URL(string: unarchivedFile.fileName)?.deletingPathExtension().lastPathComponent,
                    (!tunnelsManager.containsTunnel(named: fileBaseName)),
                    let fileContents = String(data: unarchivedFile.contents, encoding: .utf8),
                    let tunnelConfiguration = try? WgQuickConfigFileParser.parse(fileContents, name: fileBaseName) {
                    tunnelConfigurationsToAdd.append(tunnelConfiguration)
                } else {
                    numberOfConfigFilesWithErrors = numberOfConfigFilesWithErrors + 1
                }
            }
            guard (tunnelConfigurationsToAdd.count > 0) else {
                showErrorAlert(title: "No configurations found", message: "Zip archive does not contain any valid .conf files")
                return
            }
            var numberOfTunnelsRemainingAfterError = 0
            tunnelsManager?.addMultiple(tunnelConfigurations: tunnelConfigurationsToAdd) { (numberOfTunnelsRemaining, error) in
                if (error != nil) {
                    numberOfTunnelsRemainingAfterError = numberOfTunnelsRemaining
                } else {
                    assert(numberOfTunnelsRemaining == 0)
                }
            }
            if (numberOfConfigFilesWithErrors > 0) {
                showErrorAlert(title: "Created \(unarchivedFiles.count) tunnels",
                    message: "Created \(numberOfTunnelsRemainingAfterError) of \(unarchivedFiles.count) tunnels from files in zip archive")
            }
        }
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
            importFromFile(url: url)
        }
    }
}

// MARK: QRScanViewControllerDelegate

extension TunnelsListTableViewController: QRScanViewControllerDelegate {
    func addScannedQRCode(tunnelConfiguration: TunnelConfiguration, qrScanViewController: QRScanViewController,
                       completionHandler: (() ->Void)?) {
        tunnelsManager?.add(tunnelConfiguration: tunnelConfiguration) { (tunnel, error) in
            if let error = error {
                ErrorPresenter.showErrorAlert(error: error, from: qrScanViewController, onDismissal: completionHandler)
            } else {
                completionHandler?()
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
                    tunnelsManager.startActivation(of: tunnel) { [weak s] error in
                        if let error = error {
                            ErrorPresenter.showErrorAlert(error: error, from: s)
                            DispatchQueue.main.async {
                                cell.statusSwitch.isOn = false
                            }
                        }
                    }
                } else {
                    tunnelsManager.startDeactivation(of: tunnel) { [weak s] error in
                        s?.showErrorAlert(title: "Deactivation error", message: "Error while bringing down tunnel: \(String(describing: error))")
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

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete", handler: { [weak self] (_, _, completionHandler) in
            guard let tunnelsManager = self?.tunnelsManager else { return }
            let tunnel = tunnelsManager.tunnel(at: indexPath.row)
            tunnelsManager.remove(tunnel: tunnel, completionHandler: { (error) in
                if (error != nil) {
                    ErrorPresenter.showErrorAlert(error: error!, from: self)
                    completionHandler(false)
                } else {
                    completionHandler(true)
                }
            })
        })
        return UISwipeActionsConfiguration(actions: [deleteAction])
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

    func tunnelRemoved(at index: Int) {
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
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
