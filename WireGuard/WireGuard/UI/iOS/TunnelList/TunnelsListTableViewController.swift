// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit
import MobileCoreServices
import UserNotifications

class TunnelsListTableViewController: UIViewController {

    var tunnelsManager: TunnelsManager?

    let tableView: UITableView = {
        let tableView = UITableView(frame: CGRect.zero, style: .plain)
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.register(TunnelListCell.self)
        return tableView
    }()
    
    let centeredAddButton: BorderedTextButton = {
        let button = BorderedTextButton()
        button.title = "Add a tunnel"
        button.isHidden = true
        return button
    }()
    
    let busyIndicator: UIActivityIndicatorView = {
        let busyIndicator = UIActivityIndicatorView(style: .gray)
        busyIndicator.hidesWhenStopped = true
        return busyIndicator
    }()
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = .white
        
        tableView.dataSource = self
        tableView.delegate = self
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.addSubview(busyIndicator)
        busyIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            busyIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            busyIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        view.addSubview(centeredAddButton)
        centeredAddButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centeredAddButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centeredAddButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        centeredAddButton.onTapped = { [weak self] in
            guard let self = self else { return }
            self.addButtonTapped(sender: self.centeredAddButton)
        }
        
        busyIndicator.startAnimating()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "WireGuard"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonTapped(sender:)))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(settingsButtonTapped(sender:)))

        restorationIdentifier = "TunnelsListVC"
    }

    func setTunnelsManager(tunnelsManager: TunnelsManager) {
        self.tunnelsManager = tunnelsManager
        tunnelsManager.tunnelsListDelegate = self
        
        busyIndicator.stopAnimating()
        tableView.reloadData()
        centeredAddButton.isHidden = tunnelsManager.numberOfTunnels() > 0
    }

    override func viewWillAppear(_: Bool) {
        // Remove selection when getting back to the list view on iPhone
        if let selectedRowIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedRowIndexPath, animated: false)
        }
    }

    @objc func addButtonTapped(sender: AnyObject) {
        guard tunnelsManager != nil else { return }
        
        let alert = UIAlertController(title: "", message: "Add a new WireGuard tunnel", preferredStyle: .actionSheet)
        let importFileAction = UIAlertAction(title: "Create from file or archive", style: .default) { [weak self] _ in
            self?.presentViewControllerForFileImport()
        }
        alert.addAction(importFileAction)

        let scanQRCodeAction = UIAlertAction(title: "Create from QR code", style: .default) { [weak self] _ in
            self?.presentViewControllerForScanningQRCode()
        }
        alert.addAction(scanQRCodeAction)

        let createFromScratchAction = UIAlertAction(title: "Create from scratch", style: .default) { [weak self] _ in
            if let self = self, let tunnelsManager = self.tunnelsManager {
                self.presentViewControllerForTunnelCreation(tunnelsManager: tunnelsManager, tunnelConfiguration: nil)
            }
        }
        alert.addAction(createFromScratchAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)

        // popoverPresentationController will be nil on iPhone and non-nil on iPad
        if let sender = sender as? UIBarButtonItem {
            alert.popoverPresentationController?.barButtonItem = sender
        } else if let sender = sender as? UIView {
            alert.popoverPresentationController?.sourceView = sender
            alert.popoverPresentationController?.sourceRect = sender.bounds
        }
        present(alert, animated: true, completion: nil)
    }

    @objc func settingsButtonTapped(sender: UIBarButtonItem!) {
        guard tunnelsManager != nil else { return }
        
        let settingsVC = SettingsTableViewController(tunnelsManager: tunnelsManager)
        let settingsNC = UINavigationController(rootViewController: settingsVC)
        settingsNC.modalPresentationStyle = .formSheet
        present(settingsNC, animated: true)
    }

    func presentViewControllerForTunnelCreation(tunnelsManager: TunnelsManager, tunnelConfiguration: TunnelConfiguration?) {
        let editVC = TunnelEditTableViewController(tunnelsManager: tunnelsManager, tunnelConfiguration: tunnelConfiguration)
        let editNC = UINavigationController(rootViewController: editVC)
        editNC.modalPresentationStyle = .formSheet
        present(editNC, animated: true)
    }

    func presentViewControllerForFileImport() {
        let documentTypes = ["com.wireguard.config.quick", String(kUTTypeText), String(kUTTypeZipArchive)]
        let filePicker = UIDocumentPickerViewController(documentTypes: documentTypes, in: .import)
        filePicker.delegate = self
        present(filePicker, animated: true)
    }

    func presentViewControllerForScanningQRCode() {
        let scanQRCodeVC = QRScanViewController()
        scanQRCodeVC.delegate = self
        let scanQRCodeNC = UINavigationController(rootViewController: scanQRCodeVC)
        scanQRCodeNC.modalPresentationStyle = .fullScreen
        present(scanQRCodeNC, animated: true)
    }

    func importFromFile(url: URL, completionHandler: (() -> Void)?) {
        guard let tunnelsManager = tunnelsManager else { return }
        if url.pathExtension == "zip" {
            ZipImporter.importConfigFiles(from: url) { [weak self] result in
                if let error = result.error {
                    ErrorPresenter.showErrorAlert(error: error, from: self)
                    return
                }
                let configs = result.value!
                tunnelsManager.addMultiple(tunnelConfigurations: configs.compactMap { $0 }) { [weak self] numberSuccessful in
                    if numberSuccessful == configs.count {
                        completionHandler?()
                        return
                    }
                    ErrorPresenter.showErrorAlert(title: "Created \(numberSuccessful) tunnels",
                        message: "Created \(numberSuccessful) of \(configs.count) tunnels from zip archive",
                        from: self, onPresented: completionHandler)
                }
            }
        } else /* if (url.pathExtension == "conf") -- we assume everything else is a conf */ {
            let fileBaseName = url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            if let fileContents = try? String(contentsOf: url),
                let tunnelConfiguration = try? WgQuickConfigFileParser.parse(fileContents, name: fileBaseName) {
                tunnelsManager.add(tunnelConfiguration: tunnelConfiguration) { [weak self] result in
                    if let error = result.error {
                        ErrorPresenter.showErrorAlert(error: error, from: self, onPresented: completionHandler)
                    } else {
                        completionHandler?()
                    }
                }
            } else {
                ErrorPresenter.showErrorAlert(title: "Unable to import tunnel",
                                              message: "An error occured when importing the tunnel configuration.",
                                              from: self, onPresented: completionHandler)
            }
        }
    }
}

// MARK: UIDocumentPickerDelegate

extension TunnelsListTableViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        urls.forEach {
            importFromFile(url: $0, completionHandler: nil)
        }
    }
}

// MARK: QRScanViewControllerDelegate

extension TunnelsListTableViewController: QRScanViewControllerDelegate {
    func addScannedQRCode(tunnelConfiguration: TunnelConfiguration, qrScanViewController: QRScanViewController,
                          completionHandler: (() -> Void)?) {
        tunnelsManager?.add(tunnelConfiguration: tunnelConfiguration) { result in
            if let error = result.error {
                ErrorPresenter.showErrorAlert(error: error, from: qrScanViewController, onDismissal: completionHandler)
            } else {
                completionHandler?()
            }
        }
    }
}

// MARK: UITableViewDataSource

extension TunnelsListTableViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (tunnelsManager?.numberOfTunnels() ?? 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: TunnelListCell = tableView.dequeueReusableCell(for: indexPath)
        if let tunnelsManager = tunnelsManager {
            let tunnel = tunnelsManager.tunnel(at: indexPath.row)
            cell.tunnel = tunnel
            cell.onSwitchToggled = { [weak self] isOn in
                guard let self = self, let tunnelsManager = self.tunnelsManager else { return }
                if isOn {
                    tunnelsManager.startActivation(of: tunnel)
                } else {
                    tunnelsManager.startDeactivation(of: tunnel)
                }
            }
        }
        return cell
    }
}

// MARK: UITableViewDelegate

extension TunnelsListTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let tunnelsManager = tunnelsManager else { return }
        let tunnel = tunnelsManager.tunnel(at: indexPath.row)
        let tunnelDetailVC = TunnelDetailTableViewController(tunnelsManager: tunnelsManager,
                                                             tunnel: tunnel)
        let tunnelDetailNC = UINavigationController(rootViewController: tunnelDetailVC)
        tunnelDetailNC.restorationIdentifier = "DetailNC"
        showDetailViewController(tunnelDetailNC, sender: self) // Shall get propagated up to the split-vc
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completionHandler in
            guard let tunnelsManager = self?.tunnelsManager else { return }
            let tunnel = tunnelsManager.tunnel(at: indexPath.row)
            tunnelsManager.remove(tunnel: tunnel) { error in
                if error != nil {
                    ErrorPresenter.showErrorAlert(error: error!, from: self)
                    completionHandler(false)
                } else {
                    completionHandler(true)
                }
            }
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: TunnelsManagerDelegate

extension TunnelsListTableViewController: TunnelsManagerListDelegate {
    func tunnelAdded(at index: Int) {
        tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        centeredAddButton.isHidden = (tunnelsManager?.numberOfTunnels() ?? 0 > 0)
    }

    func tunnelModified(at index: Int) {
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
    }

    func tunnelMoved(from oldIndex: Int, to newIndex: Int) {
        tableView.moveRow(at: IndexPath(row: oldIndex, section: 0), to: IndexPath(row: newIndex, section: 0))
    }

    func tunnelRemoved(at index: Int) {
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        centeredAddButton.isHidden = tunnelsManager?.numberOfTunnels() ?? 0 > 0
    }
}
