// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

protocol TunnelsListTableViewControllerDelegate: class {
    func tunnelSelected(tunnel: TunnelContainer)
    func tunnelsListEmpty()
}

class TunnelsListTableViewController: NSViewController {

    let tunnelsManager: TunnelsManager
    weak var delegate: TunnelsListTableViewControllerDelegate?

    let tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TunnelsList")))
        tableView.headerView = nil
        tableView.rowSizeStyle = .medium
        return tableView
    }()

    let buttonBar: NSSegmentedControl = {
        let addButtonImage = NSImage(named: NSImage.addTemplateName)!
        let removeButtonImage = NSImage(named: NSImage.removeTemplateName)!
        let actionButtonImage = NSImage(named: NSImage.actionTemplateName)!
        let buttonBar = NSSegmentedControl(images: [addButtonImage, removeButtonImage, actionButtonImage],
                                           trackingMode: .momentary, target: nil, action: #selector(buttonBarClicked(sender:)))
        buttonBar.segmentStyle = .smallSquare
        buttonBar.segmentDistribution = .fit
        buttonBar.setShowsMenuIndicator(true, forSegment: 0)
        buttonBar.setShowsMenuIndicator(false, forSegment: 1)
        buttonBar.setShowsMenuIndicator(true, forSegment: 2)
        return buttonBar
    }()

    let addMenu: NSMenu = {
        let addMenu = NSMenu(title: "TunnelsListAdd")
        addMenu.addItem(withTitle: tr("macMenuAddEmptyTunnel"), action: #selector(addEmptyTunnelClicked), keyEquivalent: "")
        addMenu.addItem(withTitle: tr("macMenuImportTunnels"), action: #selector(importTunnelClicked), keyEquivalent: "")
        return addMenu
    }()

    let actionMenu: NSMenu = {
        let actionMenu = NSMenu(title: "TunnelsListAction")
        actionMenu.addItem(withTitle: tr("macMenuExportLog"), action: #selector(exportLogClicked), keyEquivalent: "")
        actionMenu.addItem(withTitle: tr("macMenuExportTunnels"), action: #selector(exportTunnelsClicked), keyEquivalent: "")
        return actionMenu
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
        let isSelected = selectTunnel(at: 0)
        if !isSelected {
            delegate?.tunnelsListEmpty()
        }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let clipView = NSClipView()
        clipView.documentView = tableView
        scrollView.contentView = clipView

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
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])

        buttonBar.target = self
        addMenu.items.forEach { $0.target = self }
        actionMenu.items.forEach { $0.target = self }

        view = containerView
    }

    @objc func buttonBarClicked(sender: AnyObject?) {
        guard let buttonBar = sender as? NSSegmentedControl else { return }
        // We have to resort to explicitly showing the menu instead of using NSSegmentedControl.setMenu()
        // because we have a mix of menu and non-menu segments.
        // See: http://openradar.appspot.com/radar?id=61419
        if buttonBar.selectedSegment == 0 {
            let segmentBottomLeft = NSPoint(x: 0, y: buttonBar.bounds.height + 2)
            addMenu.popUp(positioning: nil, at: segmentBottomLeft, in: buttonBar)
        } else if buttonBar.selectedSegment == 1 {
            removeTunnelClicked()
        } else if buttonBar.selectedSegment == 2 {
            let segmentBottomLeft = NSPoint(x: buttonBar.bounds.width * 0.66, y: buttonBar.bounds.height + 2)
            actionMenu.popUp(positioning: nil, at: segmentBottomLeft, in: buttonBar)
        }
    }

    @objc func addEmptyTunnelClicked() {
        let tunnelEditVC = TunnelEditViewController(tunnelsManager: tunnelsManager, tunnel: nil)
        presentAsSheet(tunnelEditVC)
    }

    @objc func importTunnelClicked() {
        ImportPanelPresenter.presentImportPanel(tunnelsManager: tunnelsManager, sourceVC: self)
    }

    @objc func removeTunnelClicked() {
        guard let window = view.window else { return }
        let selectedTunnelIndex = tableView.selectedRow
        guard selectedTunnelIndex >= 0 && selectedTunnelIndex < tunnelsManager.numberOfTunnels() else { return }
        let selectedTunnel = tunnelsManager.tunnel(at: selectedTunnelIndex)
        let alert = NSAlert()
        alert.messageText = tr(format: "macDeleteTunnelConfirmationAlertMessage (%@)", selectedTunnel.name)
        alert.informativeText = tr("macDeleteTunnelConfirmationAlertInfo")
        alert.addButton(withTitle: tr("macDeleteTunnelConfirmationAlertButtonTitleDelete"))
        alert.addButton(withTitle: tr("macDeleteTunnelConfirmationAlertButtonTitleCancel"))
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.buttonBar.setEnabled(false, forSegment: 1)
            self?.tunnelsManager.remove(tunnel: selectedTunnel) { [weak self] error in
                guard let self = self else { return }
                defer { self.buttonBar.setEnabled(true, forSegment: 1) }
                if let error = error {
                    ErrorPresenter.showErrorAlert(error: error, from: self)
                    return
                }
                let tunnelIndex = min(selectedTunnelIndex, self.tunnelsManager.numberOfTunnels() - 1)
                if tunnelIndex >= 0 {
                    self.selectTunnel(at: tunnelIndex)
                }
            }
        }
    }

    @objc func exportLogClicked() {
        guard let window = view.window else { return }
        let savePanel = NSSavePanel()
        savePanel.prompt = tr("macSheetButtonExportLog")
        savePanel.nameFieldLabel = tr("macNameFieldExportLog")

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withTimeZone] // Avoid ':' in the filename
        let timeStampString = dateFormatter.string(from: Date())
        savePanel.nameFieldStringValue = "wireguard-log-\(timeStampString).txt"

        guard let networkExtensionLogFilePath = FileManager.networkExtensionLogFileURL?.path else {
            ErrorPresenter.showErrorAlert(title: tr("alertUnableToFindExtensionLogPathTitle"), message: tr("alertUnableToFindExtensionLogPathMessage"), from: self)
            return
        }

        savePanel.beginSheetModal(for: window) { response in
            guard response == .OK else { return }
            guard let destinationURL = savePanel.url else { return }

            DispatchQueue.global(qos: .userInitiated).async {
                let isWritten = Logger.global?.writeLog(called: "APP", mergedWith: networkExtensionLogFilePath, called: "NET", to: destinationURL.path) ?? false
                guard isWritten else {
                    DispatchQueue.main.async { [weak self] in
                        ErrorPresenter.showErrorAlert(title: tr("alertUnableToWriteLogTitle"), message: tr("alertUnableToWriteLogMessage"), from: self)
                    }
                    return
                }
            }

        }
    }

    @objc func exportTunnelsClicked() {
        guard let window = view.window else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["zip"]
        savePanel.prompt = tr("macSheetButtonExportZip")
        savePanel.nameFieldLabel = tr("macNameFieldExportZip")
        savePanel.nameFieldStringValue = "wireguard-export.zip"
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

    @discardableResult
    private func selectTunnel(at index: Int) -> Bool {
        if index < tunnelsManager.numberOfTunnels() {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            return true
        }
        return false
    }
}

extension TunnelsListTableViewController {
    func tunnelAdded(at index: Int) {
        tableView.insertRows(at: IndexSet(integer: index), withAnimation: .slideLeft)
        if tunnelsManager.numberOfTunnels() == 1 {
            selectTunnel(at: 0)
        }
    }

    func tunnelModified(at index: Int) {
        tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: 0))
    }

    func tunnelMoved(from oldIndex: Int, to newIndex: Int) {
        tableView.moveRow(at: oldIndex, to: newIndex)
    }

    func tunnelRemoved(at index: Int) {
        tableView.removeRows(at: IndexSet(integer: index), withAnimation: .slideLeft)
        if tunnelsManager.numberOfTunnels() == 0 {
            delegate?.tunnelsListEmpty()
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
        guard tableView.selectedRow >= 0 else { return }
        let selectedTunnel = tunnelsManager.tunnel(at: tableView.selectedRow)
        delegate?.tunnelSelected(tunnel: selectedTunnel)
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
