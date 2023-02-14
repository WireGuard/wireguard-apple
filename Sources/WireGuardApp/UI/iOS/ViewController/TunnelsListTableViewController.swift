// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit
import MobileCoreServices
import UserNotifications

class TunnelsListTableViewController: UIViewController {

    var tunnelsManager: TunnelsManager?

    enum TableState: Equatable {
        case normal
        case rowSwiped
        case multiSelect(selectionCount: Int)
    }

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
        button.title = tr("tunnelsListCenteredAddTunnelButtonTitle")
        button.isHidden = true
        return button
    }()

    let busyIndicator: UIActivityIndicatorView = {
        let busyIndicator: UIActivityIndicatorView
        busyIndicator = UIActivityIndicatorView(style: .medium)
        busyIndicator.hidesWhenStopped = true
        return busyIndicator
    }()

    var detailDisplayedTunnel: TunnelContainer?
    var tableState: TableState = .normal {
        didSet {
            handleTableStateChange()
        }
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBackground

        tableView.dataSource = self
        tableView.delegate = self

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
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

        tableState = .normal
        restorationIdentifier = "TunnelsListVC"
    }

    func handleTableStateChange() {
        switch tableState {
        case .normal:
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonTapped(sender:)))
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: tr("tunnelsListSettingsButtonTitle"), style: .plain, target: self, action: #selector(settingsButtonTapped(sender:)))
        case .rowSwiped:
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: tr("tunnelsListSelectButtonTitle"), style: .plain, target: self, action: #selector(selectButtonTapped))
        case .multiSelect(let selectionCount):
            if selectionCount > 0 {
                navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTapped))
                navigationItem.leftBarButtonItem = UIBarButtonItem(title: tr("tunnelsListDeleteButtonTitle"), style: .plain, target: self, action: #selector(deleteButtonTapped(sender:)))
            } else {
                navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTapped))
                navigationItem.leftBarButtonItem = UIBarButtonItem(title: tr("tunnelsListSelectAllButtonTitle"), style: .plain, target: self, action: #selector(selectAllButtonTapped))
            }
        }
        if case .multiSelect(let selectionCount) = tableState, selectionCount > 0 {
            navigationItem.title = tr(format: "tunnelsListSelectedTitle (%d)", selectionCount)
        } else {
            navigationItem.title = tr("tunnelsListTitle")
        }
        if case .multiSelect = tableState {
            tableView.allowsMultipleSelectionDuringEditing = true
        } else {
            tableView.allowsMultipleSelectionDuringEditing = false
        }
    }

    func setTunnelsManager(tunnelsManager: TunnelsManager) {
        self.tunnelsManager = tunnelsManager
        tunnelsManager.tunnelsListDelegate = self

        busyIndicator.stopAnimating()
        tableView.reloadData()
        centeredAddButton.isHidden = tunnelsManager.numberOfTunnels() > 0
    }

    override func viewWillAppear(_: Bool) {
        if let selectedRowIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedRowIndexPath, animated: false)
        }
    }

    @objc func addButtonTapped(sender: AnyObject) {
        guard tunnelsManager != nil else { return }

        let alert = UIAlertController(title: "", message: tr("addTunnelMenuHeader"), preferredStyle: .actionSheet)
        let importFileAction = UIAlertAction(title: tr("addTunnelMenuImportFile"), style: .default) { [weak self] _ in
            self?.presentViewControllerForFileImport()
        }
        alert.addAction(importFileAction)

        let scanQRCodeAction = UIAlertAction(title: tr("addTunnelMenuQRCode"), style: .default) { [weak self] _ in
            self?.presentViewControllerForScanningQRCode()
        }
        alert.addAction(scanQRCodeAction)

        let createFromScratchAction = UIAlertAction(title: tr("addTunnelMenuFromScratch"), style: .default) { [weak self] _ in
            if let self = self, let tunnelsManager = self.tunnelsManager {
                self.presentViewControllerForTunnelCreation(tunnelsManager: tunnelsManager)
            }
        }
        alert.addAction(createFromScratchAction)

        let cancelAction = UIAlertAction(title: tr("actionCancel"), style: .cancel)
        alert.addAction(cancelAction)

        if let sender = sender as? UIBarButtonItem {
            alert.popoverPresentationController?.barButtonItem = sender
        } else if let sender = sender as? UIView {
            alert.popoverPresentationController?.sourceView = sender
            alert.popoverPresentationController?.sourceRect = sender.bounds
        }
        present(alert, animated: true, completion: nil)
    }

    @objc func settingsButtonTapped(sender: UIBarButtonItem) {
        guard tunnelsManager != nil else { return }

        let settingsVC = SettingsTableViewController(tunnelsManager: tunnelsManager)
        let settingsNC = UINavigationController(rootViewController: settingsVC)
        settingsNC.modalPresentationStyle = .formSheet
        present(settingsNC, animated: true)
    }

    func presentViewControllerForTunnelCreation(tunnelsManager: TunnelsManager) {
        let editVC = TunnelEditTableViewController(tunnelsManager: tunnelsManager)
        let editNC = UINavigationController(rootViewController: editVC)
        editNC.modalPresentationStyle = .fullScreen
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

    @objc func selectButtonTapped() {
        let shouldCancelSwipe = tableState == .rowSwiped
        tableState = .multiSelect(selectionCount: 0)
        if shouldCancelSwipe {
            tableView.setEditing(false, animated: false)
        }
        tableView.setEditing(true, animated: true)
    }

    @objc func doneButtonTapped() {
        tableState = .normal
        tableView.setEditing(false, animated: true)
    }

    @objc func selectAllButtonTapped() {
        guard tableView.isEditing else { return }
        guard let tunnelsManager = tunnelsManager else { return }
        for index in 0 ..< tunnelsManager.numberOfTunnels() {
            tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
        }
        tableState = .multiSelect(selectionCount: tableView.indexPathsForSelectedRows?.count ?? 0)
    }

    @objc func cancelButtonTapped() {
        tableState = .normal
        tableView.setEditing(false, animated: true)
    }

    @objc func deleteButtonTapped(sender: AnyObject?) {
        guard let sender = sender as? UIBarButtonItem else { return }
        guard let tunnelsManager = tunnelsManager else { return }

        let selectedTunnelIndices = tableView.indexPathsForSelectedRows?.map { $0.row } ?? []
        let selectedTunnels = selectedTunnelIndices.compactMap { tunnelIndex in
            tunnelIndex >= 0 && tunnelIndex < tunnelsManager.numberOfTunnels() ? tunnelsManager.tunnel(at: tunnelIndex) : nil
        }
        guard !selectedTunnels.isEmpty else { return }
        let message = selectedTunnels.count == 1 ?
            tr(format: "deleteTunnelConfirmationAlertButtonMessage (%d)", selectedTunnels.count) :
            tr(format: "deleteTunnelsConfirmationAlertButtonMessage (%d)", selectedTunnels.count)
        let title = tr("deleteTunnelsConfirmationAlertButtonTitle")
        ConfirmationAlertPresenter.showConfirmationAlert(message: message, buttonTitle: title,
                                                         from: sender, presentingVC: self) { [weak self] in
            self?.tunnelsManager?.removeMultiple(tunnels: selectedTunnels) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    ErrorPresenter.showErrorAlert(error: error, from: self)
                    return
                }
                self.tableState = .normal
                self.tableView.setEditing(false, animated: true)
            }
        }
    }

    func showTunnelDetail(for tunnel: TunnelContainer, animated: Bool) {
        guard let tunnelsManager = tunnelsManager else { return }
        guard let splitViewController = splitViewController else { return }
        guard let navController = navigationController else { return }

        let tunnelDetailVC = TunnelDetailTableViewController(tunnelsManager: tunnelsManager,
                                                             tunnel: tunnel)
        let tunnelDetailNC = UINavigationController(rootViewController: tunnelDetailVC)
        tunnelDetailNC.restorationIdentifier = "DetailNC"
        if splitViewController.isCollapsed && navController.viewControllers.count > 1 {
            navController.setViewControllers([self, tunnelDetailNC], animated: animated)
        } else {
            splitViewController.showDetailViewController(tunnelDetailNC, sender: self, animated: animated)
        }
        detailDisplayedTunnel = tunnel
        self.presentedViewController?.dismiss(animated: false, completion: nil)
    }
}

extension TunnelsListTableViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let tunnelsManager = tunnelsManager else { return }
        TunnelImporter.importFromFile(urls: urls, into: tunnelsManager, sourceVC: self, errorPresenterType: ErrorPresenter.self)
    }
}

extension TunnelsListTableViewController: QRScanViewControllerDelegate {
    func addScannedQRCode(tunnelConfiguration: TunnelConfiguration, qrScanViewController: QRScanViewController,
                          completionHandler: (() -> Void)?) {
        tunnelsManager?.add(tunnelConfiguration: tunnelConfiguration) { result in
            switch result {
            case .failure(let error):
                ErrorPresenter.showErrorAlert(error: error, from: qrScanViewController, onDismissal: completionHandler)
            case .success:
                completionHandler?()
            }
        }
    }
}

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
                if tunnel.hasOnDemandRules {
                    tunnelsManager.setOnDemandEnabled(isOn, on: tunnel) { error in
                        if error == nil && !isOn {
                            tunnelsManager.startDeactivation(of: tunnel)
                        }
                    }
                } else {
                    if isOn {
                        tunnelsManager.startActivation(of: tunnel)
                    } else {
                        tunnelsManager.startDeactivation(of: tunnel)
                    }
                }
            }
        }
        return cell
    }
}

extension TunnelsListTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !tableView.isEditing else {
            tableState = .multiSelect(selectionCount: tableView.indexPathsForSelectedRows?.count ?? 0)
            return
        }
        guard let tunnelsManager = tunnelsManager else { return }
        let tunnel = tunnelsManager.tunnel(at: indexPath.row)
        showTunnelDetail(for: tunnel, animated: true)
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard !tableView.isEditing else {
            tableState = .multiSelect(selectionCount: tableView.indexPathsForSelectedRows?.count ?? 0)
            return
        }
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: tr("tunnelsListSwipeDeleteButtonTitle")) { [weak self] _, _, completionHandler in
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

    func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        if tableState == .normal {
            tableState = .rowSwiped
        }
    }

    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        if tableState == .rowSwiped {
            tableState = .normal
        }
    }
}

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

    func tunnelRemoved(at index: Int, tunnel: TunnelContainer) {
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        centeredAddButton.isHidden = tunnelsManager?.numberOfTunnels() ?? 0 > 0
        if detailDisplayedTunnel == tunnel, let splitViewController = splitViewController {
            if splitViewController.isCollapsed != false {
                (splitViewController.viewControllers[0] as? UINavigationController)?.popToRootViewController(animated: false)
            } else {
                let detailVC = UIViewController()
                detailVC.view.backgroundColor = .systemBackground
                let detailNC = UINavigationController(rootViewController: detailVC)
                splitViewController.showDetailViewController(detailNC, sender: self)
            }
            detailDisplayedTunnel = nil
            if let presentedNavController = self.presentedViewController as? UINavigationController, presentedNavController.viewControllers.first is TunnelEditTableViewController {
                self.presentedViewController?.dismiss(animated: false, completion: nil)
            }
        }
    }
}

extension UISplitViewController {
    func showDetailViewController(_ viewController: UIViewController, sender: Any?, animated: Bool) {
        if animated {
            showDetailViewController(viewController, sender: sender)
        } else {
            UIView.performWithoutAnimation {
                showDetailViewController(viewController, sender: sender)
            }
        }
    }
}
