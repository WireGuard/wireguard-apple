// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class LogViewController: NSViewController {

    enum LogColumn: String {
        case time = "Time"
        case logMessage = "LogMessage"

        func createColumn() -> NSTableColumn {
            return NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue))
        }

        func isRepresenting(tableColumn: NSTableColumn?) -> Bool {
            return tableColumn?.identifier.rawValue == rawValue
        }
    }

    private var boundsChangedNotificationToken: NotificationToken?
    private var frameChangedNotificationToken: NotificationToken?

    let scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .bezelBorder
        return scrollView
    }()

    let tableView: NSTableView = {
        let tableView = NSTableView()
        let timeColumn = LogColumn.time.createColumn()
        timeColumn.title = tr("macLogColumnTitleTime")
        timeColumn.width = 160
        timeColumn.resizingMask = []
        tableView.addTableColumn(timeColumn)
        let messageColumn = LogColumn.logMessage.createColumn()
        messageColumn.title = tr("macLogColumnTitleLogMessage")
        messageColumn.minWidth = 360
        messageColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(messageColumn)
        tableView.rowSizeStyle = .custom
        tableView.rowHeight = 16
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.usesAutomaticRowHeights = true
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = true
        tableView.allowsMultipleSelection = true
        return tableView
    }()

    let progressIndicator: NSProgressIndicator = {
        let progressIndicator = NSProgressIndicator()
        progressIndicator.controlSize = .small
        progressIndicator.isIndeterminate = true
        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        return progressIndicator
    }()

    let closeButton: NSButton = {
        let button = NSButton()
        button.title = tr("macLogButtonTitleClose")
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        return button
    }()

    let saveButton: NSButton = {
        let button = NSButton()
        button.title = tr("macLogButtonTitleSave")
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        return button
    }()

    let logViewHelper: LogViewHelper?
    var logEntries = [LogViewHelper.LogEntry]()
    var isFetchingLogEntries = false
    var isInScrolledToEndMode = true

    private var updateLogEntriesTimer: Timer?

    init() {
        logViewHelper = LogViewHelper(logFilePath: FileManager.logFileURL?.path)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        tableView.dataSource = self
        tableView.delegate = self

        closeButton.target = self
        closeButton.action = #selector(closeClicked)

        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        saveButton.isEnabled = false

        let clipView = NSClipView()
        clipView.documentView = tableView
        scrollView.contentView = clipView

        boundsChangedNotificationToken = NotificationCenter.default.observe(name: NSView.boundsDidChangeNotification, object: clipView, queue: OperationQueue.main) { [weak self] _ in
            guard let self = self else { return }
            let lastVisibleRowIndex = self.tableView.row(at: NSPoint(x: 0, y: self.scrollView.contentView.documentVisibleRect.maxY - 1))
            self.isInScrolledToEndMode = lastVisibleRowIndex < 0 || lastVisibleRowIndex == self.logEntries.count - 1
        }

        frameChangedNotificationToken = NotificationCenter.default.observe(name: NSView.frameDidChangeNotification, object: tableView, queue: OperationQueue.main) { [weak self] _ in
            guard let self = self else { return }
            if self.isInScrolledToEndMode {
                DispatchQueue.main.async {
                    self.tableView.scroll(NSPoint(x: 0, y: self.tableView.frame.maxY - clipView.documentVisibleRect.height))
                }
            }
        }

        let margin: CGFloat = 20
        let internalSpacing: CGFloat = 10

        let buttonRowStackView = NSStackView()
        buttonRowStackView.addView(closeButton, in: .leading)
        buttonRowStackView.addView(saveButton, in: .trailing)
        buttonRowStackView.orientation = .horizontal
        buttonRowStackView.spacing = internalSpacing

        let containerView = NSView()
        [scrollView, progressIndicator, buttonRowStackView].forEach { view in
            containerView.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: margin),
            scrollView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: margin),
            containerView.rightAnchor.constraint(equalTo: scrollView.rightAnchor, constant: margin),
            buttonRowStackView.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: internalSpacing),
            buttonRowStackView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: margin),
            containerView.rightAnchor.constraint(equalTo: buttonRowStackView.rightAnchor, constant: margin),
            containerView.bottomAnchor.constraint(equalTo: buttonRowStackView.bottomAnchor, constant: margin),
            progressIndicator.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])

        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 640),
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 1200),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])

        containerView.frame = NSRect(x: 0, y: 0, width: 640, height: 480)

        view = containerView

        progressIndicator.startAnimation(self)
        startUpdatingLogEntries()
    }

    func updateLogEntries() {
        guard !isFetchingLogEntries else { return }
        isFetchingLogEntries = true
        logViewHelper?.fetchLogEntriesSinceLastFetch { [weak self] fetchedLogEntries in
            guard let self = self else { return }
            defer {
                self.isFetchingLogEntries = false
            }
            if !self.progressIndicator.isHidden {
                self.progressIndicator.stopAnimation(self)
                self.saveButton.isEnabled = true
            }
            guard !fetchedLogEntries.isEmpty else { return }
            let oldCount = self.logEntries.count
            self.logEntries.append(contentsOf: fetchedLogEntries)
            self.tableView.insertRows(at: IndexSet(integersIn: oldCount ..< oldCount + fetchedLogEntries.count), withAnimation: .slideDown)
        }
    }

    func startUpdatingLogEntries() {
        updateLogEntries()
        updateLogEntriesTimer?.invalidate()
        let timer = Timer(timeInterval: 1 /* second */, repeats: true) { [weak self] _ in
            self?.updateLogEntries()
        }
        updateLogEntriesTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopUpdatingLogEntries() {
        updateLogEntriesTimer?.invalidate()
        updateLogEntriesTimer = nil
    }

    override func viewWillAppear() {
        view.window?.setFrameAutosaveName(NSWindow.FrameAutosaveName("LogWindow"))
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        stopUpdatingLogEntries()
    }

    @objc func saveClicked() {
        let savePanel = NSSavePanel()
        savePanel.prompt = tr("macSheetButtonExportLog")
        savePanel.nameFieldLabel = tr("macNameFieldExportLog")

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withTimeZone] // Avoid ':' in the filename
        let timeStampString = dateFormatter.string(from: Date())
        savePanel.nameFieldStringValue = "wireguard-log-\(timeStampString).txt"

        savePanel.beginSheetModal(for: self.view.window!) { [weak self] response in
            guard response == .OK else { return }
            guard let destinationURL = savePanel.url else { return }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let isWritten = Logger.global?.writeLog(to: destinationURL.path) ?? false
                guard isWritten else {
                    DispatchQueue.main.async { [weak self] in
                        ErrorPresenter.showErrorAlert(title: tr("alertUnableToWriteLogTitle"), message: tr("alertUnableToWriteLogMessage"), from: self)
                    }
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.presentingViewController?.dismiss(self)
                }
            }

        }
    }

    @objc func closeClicked() {
        presentingViewController?.dismiss(self)
    }

    @objc func copy(_ sender: Any?) {
        let text = tableView.selectedRowIndexes.sorted().reduce("") { $0 + self.logEntries[$1].text() + "\n" }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([text as NSString])
    }
}

extension LogViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return logEntries.count
    }
}

extension LogViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if LogColumn.time.isRepresenting(tableColumn: tableColumn) {
            let cell: LogViewTimestampCell = tableView.dequeueReusableCell()
            cell.text = logEntries[row].timestamp
            return cell
        } else if LogColumn.logMessage.isRepresenting(tableColumn: tableColumn) {
            let cell: LogViewMessageCell = tableView.dequeueReusableCell()
            cell.text = logEntries[row].message
            return cell
        } else {
            fatalError()
        }
    }
}

extension LogViewController {
    override func cancelOperation(_ sender: Any?) {
        closeClicked()
    }
}
