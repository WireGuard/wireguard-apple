// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

protocol TunnelsListTableViewControllerDelegate: AnyObject {
    func tunnelsSelected(tunnelIndices: [Int])
    func tunnelsListEmpty()
}

class TunnelsListTableViewController: NSViewController {

    let tunnelsManager: TunnelsManager
    weak var delegate: TunnelsListTableViewControllerDelegate?
    var isRemovingTunnelsFromWithinTheApp = false

    let tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TunnelsList")))
        tableView.headerView = nil
        tableView.rowSizeStyle = .medium
        tableView.allowsMultipleSelection = true
        return tableView
    }()

    let addButton: NSPopUpButton = {
        let imageItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        imageItem.image = NSImage(named: NSImage.addTemplateName)!

        let menu = NSMenu()
        menu.addItem(imageItem)
        menu.addItem(withTitle: tr("macMenuAddEmptyTunnel"), action: #selector(handleAddEmptyTunnelAction), keyEquivalent: "n")
        menu.addItem(withTitle: tr("macMenuImportTunnels"), action: #selector(handleImportTunnelAction), keyEquivalent: "o")
        menu.autoenablesItems = false

        let button = NSPopUpButton(frame: NSRect.zero, pullsDown: true)
        button.menu = menu
        button.bezelStyle = .smallSquare
        (button.cell as? NSPopUpButtonCell)?.arrowPosition = .arrowAtBottom
        return button
    }()

    let removeButton: NSButton = {
        let image = NSImage(named: NSImage.removeTemplateName)!
        let button = NSButton(image: image, target: self, action: #selector(handleRemoveTunnelAction))
        button.bezelStyle = .smallSquare
        button.imagePosition = .imageOnly
        return button
    }()

    let actionButton: NSPopUpButton = {
        let imageItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        imageItem.image = NSImage(named: NSImage.actionTemplateName)!

        let menu = NSMenu()
        menu.addItem(imageItem)
        menu.addItem(withTitle: tr("macMenuViewLog"), action: #selector(handleViewLogAction), keyEquivalent: "")
        menu.addItem(withTitle: tr("macMenuExportTunnels"), action: #selector(handleExportTunnelsAction), keyEquivalent: "")
        menu.autoenablesItems = false

        let button = NSPopUpButton(frame: NSRect.zero, pullsDown: true)
        button.menu = menu
        button.bezelStyle = .smallSquare
        (button.cell as? NSPopUpButtonCell)?.arrowPosition = .arrowAtBottom
        return button
    }()

    init(tunnelsManager: TunnelsManager) {
        self.tunnelsManager = tunnelsManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        tableView.dataSource = self
        tableView.delegate = self

        tableView.doubleAction = #selector(listDoubleClicked(sender:))

        let isSelected = selectTunnelInOperation() || selectTunnel(at: 0)
        if !isSelected {
            delegate?.tunnelsListEmpty()
        }
        tableView.allowsEmptySelection = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let clipView = NSClipView()
        clipView.documentView = tableView
        scrollView.contentView = clipView

        let buttonBar = NSStackView(views: [addButton, removeButton, actionButton])
        buttonBar.orientation = .horizontal
        buttonBar.spacing = -1

        NSLayoutConstraint.activate([
            removeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 26),
            removeButton.topAnchor.constraint(equalTo: buttonBar.topAnchor),
            removeButton.bottomAnchor.constraint(equalTo: buttonBar.bottomAnchor)
        ])

        let fillerButton = FillerButton()

        let containerView = NSView()
        containerView.addSubview(scrollView)
        containerView.addSubview(buttonBar)
        containerView.addSubview(fillerButton)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        fillerButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: buttonBar.topAnchor, constant: 1),
            containerView.leadingAnchor.constraint(equalTo: buttonBar.leadingAnchor),
            containerView.bottomAnchor.constraint(equalTo: buttonBar.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: fillerButton.topAnchor, constant: 1),
            containerView.bottomAnchor.constraint(equalTo: fillerButton.bottomAnchor),
            buttonBar.trailingAnchor.constraint(equalTo: fillerButton.leadingAnchor, constant: 1),
            fillerButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])

        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalToConstant: 180),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])

        addButton.menu?.items.forEach { $0.target = self }
        actionButton.menu?.items.forEach { $0.target = self }

        view = containerView
    }

    override func viewWillAppear() {
        selectTunnelInOperation()
    }

    @discardableResult
    func selectTunnelInOperation() -> Bool {
        if let currentTunnel = tunnelsManager.tunnelInOperation(), let indexToSelect = tunnelsManager.index(of: currentTunnel) {
            return selectTunnel(at: indexToSelect)
        }
        return false
    }

    @objc func handleAddEmptyTunnelAction() {
        let tunnelEditVC = TunnelEditViewController(tunnelsManager: tunnelsManager, tunnel: nil)
        tunnelEditVC.delegate = self
        presentAsSheet(tunnelEditVC)
    }

    @objc func handleImportTunnelAction() {
        ImportPanelPresenter.presentImportPanel(tunnelsManager: tunnelsManager, sourceVC: self)
    }

    @objc func handleRemoveTunnelAction() {
        guard let window = view.window else { return }

        let selectedTunnelIndices = tableView.selectedRowIndexes.sorted().filter { $0 >= 0 && $0 < tunnelsManager.numberOfTunnels() }
        guard !selectedTunnelIndices.isEmpty else { return }
        var nextSelection = selectedTunnelIndices.last! + 1
        if nextSelection >= tunnelsManager.numberOfTunnels() {
            nextSelection = max(selectedTunnelIndices.first! - 1, 0)
        }

        let alert = DeleteTunnelsConfirmationAlert()
        if selectedTunnelIndices.count == 1 {
            let firstSelectedTunnel = tunnelsManager.tunnel(at: selectedTunnelIndices.first!)
            alert.messageText = tr(format: "macDeleteTunnelConfirmationAlertMessage (%@)", firstSelectedTunnel.name)
        } else {
            alert.messageText = tr(format: "macDeleteMultipleTunnelsConfirmationAlertMessage (%d)", selectedTunnelIndices.count)
        }
        alert.informativeText = tr("macDeleteTunnelConfirmationAlertInfo")
        alert.onDeleteClicked = { [weak self] completion in
            guard let self = self else { return }
            self.selectTunnel(at: nextSelection)
            let selectedTunnels = selectedTunnelIndices.map { self.tunnelsManager.tunnel(at: $0) }
            self.isRemovingTunnelsFromWithinTheApp = true
            self.tunnelsManager.removeMultiple(tunnels: selectedTunnels) { [weak self] error in
                guard let self = self else { return }
                self.isRemovingTunnelsFromWithinTheApp = false
                defer { completion() }
                if let error = error {
                    ErrorPresenter.showErrorAlert(error: error, from: self)
                    return
                }
             }
        }
        alert.beginSheetModal(for: window)
    }

    @objc func handleViewLogAction() {
        let logVC = LogViewController()
        self.presentAsSheet(logVC)
    }

    @objc func handleExportTunnelsAction() {
        PrivateDataConfirmation.confirmAccess(to: tr("macExportPrivateData")) { [weak self] in
            guard let self = self else { return }
            guard let window = self.view.window else { return }
            let savePanel = NSSavePanel()
            savePanel.allowedFileTypes = ["zip"]
            savePanel.prompt = tr("macSheetButtonExportZip")
            savePanel.nameFieldLabel = tr("macNameFieldExportZip")
            savePanel.nameFieldStringValue = "wireguard-export.zip"
            let tunnelsManager = self.tunnelsManager
            savePanel.beginSheetModal(for: window) { [weak tunnelsManager] response in
                guard let tunnelsManager = tunnelsManager else { return }
                guard response == .OK else { return }
                guard let destinationURL = savePanel.url else { return }
                let count = tunnelsManager.numberOfTunnels()
                let tunnelConfigurations = (0 ..< count).compactMap { tunnelsManager.tunnel(at: $0).tunnelConfiguration }
                ZipExporter.exportConfigFiles(tunnelConfigurations: tunnelConfigurations, to: destinationURL) { [weak self] error in
                    if let error = error {
                        ErrorPresenter.showErrorAlert(error: error, from: self)
                        return
                    }
                }
            }
        }
    }

    @objc func listDoubleClicked(sender: AnyObject) {
        let tunnelIndex = tableView.clickedRow
        guard tunnelIndex >= 0 && tunnelIndex < tunnelsManager.numberOfTunnels() else { return }
        let tunnel = tunnelsManager.tunnel(at: tunnelIndex)
        if tunnel.hasOnDemandRules {
            let turnOn = !tunnel.isActivateOnDemandEnabled
            tunnelsManager.setOnDemandEnabled(turnOn, on: tunnel) { error in
                if error == nil && !turnOn {
                    self.tunnelsManager.startDeactivation(of: tunnel)
                }
            }
        } else {
            if tunnel.status == .inactive {
                tunnelsManager.startActivation(of: tunnel)
            } else if tunnel.status == .active {
                tunnelsManager.startDeactivation(of: tunnel)
            }
        }
    }

    @discardableResult
    private func selectTunnel(at index: Int) -> Bool {
        if index < tunnelsManager.numberOfTunnels() {
            tableView.scrollRowToVisible(index)
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            return true
        }
        return false
    }
}

extension TunnelsListTableViewController: TunnelEditViewControllerDelegate {
    func tunnelSaved(tunnel: TunnelContainer) {
        if let tunnelIndex = tunnelsManager.index(of: tunnel), tunnelIndex >= 0 {
            self.selectTunnel(at: tunnelIndex)
        }
    }

    func tunnelEditingCancelled() {
        // Nothing to do
    }
}

extension TunnelsListTableViewController {
    func tunnelAdded(at index: Int) {
        tableView.insertRows(at: IndexSet(integer: index), withAnimation: .slideLeft)
        if tunnelsManager.numberOfTunnels() == 1 {
            selectTunnel(at: 0)
        }
        if !NSApp.isActive {
            // macOS's VPN prompt might have caused us to lose focus
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func tunnelModified(at index: Int) {
        tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: 0))
    }

    func tunnelMoved(from oldIndex: Int, to newIndex: Int) {
        tableView.moveRow(at: oldIndex, to: newIndex)
    }

    func tunnelRemoved(at index: Int) {
        let selectedIndices = tableView.selectedRowIndexes
        let isSingleSelectedTunnelBeingRemoved = selectedIndices.contains(index) && selectedIndices.count == 1
        tableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideLeft)
        if tunnelsManager.numberOfTunnels() == 0 {
            delegate?.tunnelsListEmpty()
        } else if !isRemovingTunnelsFromWithinTheApp && isSingleSelectedTunnelBeingRemoved {
            let newSelection = min(index, tunnelsManager.numberOfTunnels() - 1)
            tableView.selectRowIndexes(IndexSet(integer: newSelection), byExtendingSelection: false)
        }
    }
}

extension TunnelsListTableViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tunnelsManager.numberOfTunnels()
    }
}

extension TunnelsListTableViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell: TunnelListRow = tableView.dequeueReusableCell()
        cell.tunnel = tunnelsManager.tunnel(at: row)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedTunnelIndices = tableView.selectedRowIndexes.sorted()
        if !selectedTunnelIndices.isEmpty {
            delegate?.tunnelsSelected(tunnelIndices: tableView.selectedRowIndexes.sorted())
        }
    }
}

extension TunnelsListTableViewController {
    override func keyDown(with event: NSEvent) {
        if event.specialKey == .delete {
            handleRemoveTunnelAction()
        }
    }
}

extension TunnelsListTableViewController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(TunnelsListTableViewController.handleRemoveTunnelAction) {
            return !tableView.selectedRowIndexes.isEmpty
        }
        return true
    }
}

class FillerButton: NSButton {
    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    init() {
        super.init(frame: CGRect.zero)
        title = ""
        bezelStyle = .smallSquare
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        // Eat mouseDown event, so that the button looks enabled but is unresponsive
    }
}
