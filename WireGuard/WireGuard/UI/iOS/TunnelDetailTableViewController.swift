// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

// MARK: TunnelDetailTableViewController

class TunnelDetailTableViewController: UITableViewController {

    private enum Section {
        case status
        case interface
        case peer(_ peer: TunnelViewModel.PeerData)
        case onDemand
        case delete
    }

    let interfaceFields: [TunnelViewModel.InterfaceField] = [
        .name, .publicKey, .addresses,
        .listenPort, .mtu, .dns
    ]

    let peerFields: [TunnelViewModel.PeerField] = [
        .publicKey, .preSharedKey, .endpoint,
        .allowedIPs, .persistentKeepAlive
    ]

    let tunnelsManager: TunnelsManager
    let tunnel: TunnelContainer
    var tunnelViewModel: TunnelViewModel
    private var sections = [Section]()

    init(tunnelsManager: TunnelsManager, tunnel: TunnelContainer) {
        self.tunnelsManager = tunnelsManager
        self.tunnel = tunnel
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration())
        super.init(style: .grouped)
        loadSections()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = tunnelViewModel.interfaceData[.name]
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editTapped))

        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.allowsSelection = false
        self.tableView.register(StatusCell.self)
        self.tableView.register(KeyValueCell.self)
        self.tableView.register(ButtonCell.self)
        self.tableView.register(ActivateOnDemandCell.self)

        // State restoration
        self.restorationIdentifier = "TunnelDetailVC:\(tunnel.name)"
    }

    private func loadSections() {
        sections.removeAll()
        sections.append(.status)
        sections.append(.interface)
        tunnelViewModel.peersData.forEach { sections.append(.peer($0)) }
        sections.append(.onDemand)
        sections.append(.delete)
    }

    @objc func editTapped() {
        let editVC = TunnelEditTableViewController(tunnelsManager: tunnelsManager, tunnel: tunnel)
        editVC.delegate = self
        let editNC = UINavigationController(rootViewController: editVC)
        editNC.modalPresentationStyle = .formSheet
        present(editNC, animated: true)
    }

    func showConfirmationAlert(message: String, buttonTitle: String, from sourceView: UIView,
                               onConfirmed: @escaping (() -> Void)) {
        let destroyAction = UIAlertAction(title: buttonTitle, style: .destructive) { _ in
            onConfirmed()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let alert = UIAlertController(title: "", message: message, preferredStyle: .actionSheet)
        alert.addAction(destroyAction)
        alert.addAction(cancelAction)

        // popoverPresentationController will be nil on iPhone and non-nil on iPad
        alert.popoverPresentationController?.sourceView = sourceView
        alert.popoverPresentationController?.sourceRect = sourceView.bounds

        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: TunnelEditTableViewControllerDelegate

extension TunnelDetailTableViewController: TunnelEditTableViewControllerDelegate {
    func tunnelSaved(tunnel: TunnelContainer) {
        tunnelViewModel = TunnelViewModel(tunnelConfiguration: tunnel.tunnelConfiguration())
        loadSections()
        self.title = tunnel.name
        self.tableView.reloadData()
    }
    func tunnelEditingCancelled() {
        // Nothing to do
    }
}

// MARK: UITableViewDataSource

extension TunnelDetailTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .status:
            return 1
        case .interface:
             return tunnelViewModel.interfaceData.filterFieldsWithValueOrControl(interfaceFields: interfaceFields).count
        case .peer(let peerData):
            return peerData.filterFieldsWithValueOrControl(peerFields: peerFields).count
        case .onDemand:
            return 1
        case .delete:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .status:
            return "Status"
        case .interface:
            return "Interface"
        case .peer:
            return "Peer"
        case .onDemand:
            return "On-Demand Activation"
        case .delete:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .status:
            return statusCell(for: tableView, at: indexPath)
        case .interface:
            return interfaceCell(for: tableView, at: indexPath)
        case .peer(let peer):
            return peerCell(for: tableView, at: indexPath, with: peer)
        case .onDemand:
            return onDemandCell(for: tableView, at: indexPath)
        case .delete:
            return deleteConfigurationCell(for: tableView, at: indexPath)
        }
    }

    private func statusCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: StatusCell = tableView.dequeueReusableCell(for: indexPath)
        cell.tunnel = self.tunnel
        cell.onSwitchToggled = { [weak self] isOn in
            guard let self = self else { return }
            if isOn {
                self.tunnelsManager.startActivation(of: self.tunnel) { [weak self] error in
                    if let error = error {
                        ErrorPresenter.showErrorAlert(error: error, from: self) {
                            DispatchQueue.main.async {
                                cell.statusSwitch.isOn = false
                            }
                        }
                    }
                }
            } else {
                self.tunnelsManager.startDeactivation(of: self.tunnel)
            }
        }
        return cell
    }

    private func interfaceCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let field = tunnelViewModel.interfaceData.filterFieldsWithValueOrControl(interfaceFields: interfaceFields)[indexPath.row]
        let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.rawValue
        cell.value = tunnelViewModel.interfaceData[field]
        return cell
    }

    private func peerCell(for tableView: UITableView, at indexPath: IndexPath, with peerData: TunnelViewModel.PeerData) -> UITableViewCell {
        let field = peerData.filterFieldsWithValueOrControl(peerFields: peerFields)[indexPath.row]
        let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
        cell.key = field.rawValue
        cell.value = peerData[field]
        return cell
    }

    private func onDemandCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: ActivateOnDemandCell = tableView.dequeueReusableCell(for: indexPath)
        cell.tunnel = self.tunnel
        return cell
    }

    private func deleteConfigurationCell(for tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)
        cell.buttonText = "Delete tunnel"
        cell.hasDestructiveAction = true
        cell.onTapped = { [weak self] in
            guard let self = self else { return }
            self.showConfirmationAlert(message: "Delete this tunnel?", buttonTitle: "Delete", from: cell) { [weak self] in
                guard let tunnelsManager = self?.tunnelsManager, let tunnel = self?.tunnel else { return }
                tunnelsManager.remove(tunnel: tunnel) { error in
                    if error != nil {
                        print("Error removing tunnel: \(String(describing: error))")
                        return
                    }
                }
                self?.navigationController?.navigationController?.popToRootViewController(animated: true)
            }
        }
        return cell
    }

}

private class StatusCell: UITableViewCell {
    var tunnel: TunnelContainer? {
        didSet(value) {
            update(from: tunnel?.status)
            statusObservervationToken = tunnel?.observe(\.status) { [weak self] tunnel, _ in
                self?.update(from: tunnel.status)
            }
        }
    }
    var isSwitchInteractionEnabled: Bool {
        get { return statusSwitch.isUserInteractionEnabled }
        set(value) { statusSwitch.isUserInteractionEnabled = value }
    }
    var onSwitchToggled: ((Bool) -> Void)?
    private var isOnSwitchToggledHandlerEnabled: Bool = true

    let statusSwitch: UISwitch
    private var statusObservervationToken: AnyObject?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        statusSwitch = UISwitch()
        super.init(style: .default, reuseIdentifier: KeyValueCell.reuseIdentifier)
        accessoryView = statusSwitch

        statusSwitch.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
    }

    @objc func switchToggled() {
        if isOnSwitchToggledHandlerEnabled {
            onSwitchToggled?(statusSwitch.isOn)
        }
    }

    private func update(from status: TunnelStatus?) {
        guard let status = status else {
            reset()
            return
        }
        let text: String
        switch status {
        case .inactive:
            text = "Inactive"
        case .activating:
            text = "Activating"
        case .active:
            text = "Active"
        case .deactivating:
            text = "Deactivating"
        case .reasserting:
            text = "Reactivating"
        case .restarting:
            text = "Restarting"
        }
        textLabel?.text = text
        DispatchQueue.main.async { [weak statusSwitch] in
            guard let statusSwitch = statusSwitch else { return }
            statusSwitch.isOn = !(status == .deactivating || status == .inactive)
            statusSwitch.isUserInteractionEnabled = (status == .inactive || status == .active)
        }
        textLabel?.textColor = (status == .active || status == .inactive) ? UIColor.black : UIColor.gray
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func reset() {
        textLabel?.text = "Invalid"
        statusSwitch.isOn = false
        textLabel?.textColor = UIColor.gray
        statusSwitch.isUserInteractionEnabled = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        reset()
    }
}

private class KeyValueCell: CopyableLabelTableViewCell {
    var key: String {
        get { return keyLabel.text ?? "" }
        set(value) { keyLabel.text = value }
    }
    var value: String {
        get { return valueLabel.text }
        set(value) { valueLabel.text = value }
    }

    override var textToCopy: String? {
        return self.valueLabel.text
    }

    let keyLabel: UILabel
    let valueLabel: ScrollableLabel

    var isStackedHorizontally = false
    var isStackedVertically = false
    var contentSizeBasedConstraints = [NSLayoutConstraint]()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        keyLabel = UILabel()
        keyLabel.font = UIFont.preferredFont(forTextStyle: .body)
        keyLabel.adjustsFontForContentSizeCategory = true
        valueLabel = ScrollableLabel()
        valueLabel.label.font = UIFont.preferredFont(forTextStyle: .body)
        valueLabel.label.adjustsFontForContentSizeCategory = true

        keyLabel.textColor = UIColor.black
        valueLabel.textColor = UIColor.gray

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(keyLabel)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        keyLabel.textAlignment = .left
        NSLayoutConstraint.activate([
            keyLabel.leftAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leftAnchor),
            keyLabel.topAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.topAnchor, multiplier: 0.5)
        ])

        contentView.addSubview(valueLabel)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueLabel.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor),
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: valueLabel.bottomAnchor, multiplier: 0.5)
        ])

        // Key label should never appear truncated
        keyLabel.setContentCompressionResistancePriority(.defaultHigh + 1, for: .horizontal)
        // Key label should hug it's content; value label should not.
        keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        configureForContentSize()
    }

    func configureForContentSize() {
        var constraints = [NSLayoutConstraint]()
        if self.traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            // Stack vertically
            if !isStackedVertically {
                constraints = [
                    valueLabel.topAnchor.constraint(equalToSystemSpacingBelow: keyLabel.bottomAnchor, multiplier: 0.5),
                    valueLabel.leftAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leftAnchor),
                    keyLabel.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor)
                ]
                isStackedVertically = true
                isStackedHorizontally = false
            }
        } else {
            // Stack horizontally
            if !isStackedHorizontally {
                constraints = [
                    contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: keyLabel.bottomAnchor, multiplier: 0.5),
                    valueLabel.leftAnchor.constraint(equalToSystemSpacingAfter: keyLabel.rightAnchor, multiplier: 1),
                    valueLabel.topAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.topAnchor, multiplier: 0.5)
                ]
                isStackedHorizontally = true
                isStackedVertically = false
            }
        }
        if !constraints.isEmpty {
            NSLayoutConstraint.deactivate(self.contentSizeBasedConstraints)
            NSLayoutConstraint.activate(constraints)
            self.contentSizeBasedConstraints = constraints
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        key = ""
        value = ""
        configureForContentSize()
    }
}

private class ButtonCell: UITableViewCell {
    var buttonText: String {
        get { return button.title(for: .normal) ?? "" }
        set(value) { button.setTitle(value, for: .normal) }
    }
    var hasDestructiveAction: Bool {
        get { return button.tintColor == UIColor.red }
        set(value) { button.tintColor = value ? UIColor.red : buttonStandardTintColor }
    }
    var onTapped: (() -> Void)?

    let button: UIButton
    var buttonStandardTintColor: UIColor

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        buttonStandardTintColor = button.tintColor
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            button.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    @objc func buttonTapped() {
        onTapped?()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        buttonText = ""
        onTapped = nil
        hasDestructiveAction = false
    }
}

private class ActivateOnDemandCell: UITableViewCell {
    var tunnel: TunnelContainer? {
        didSet(value) {
            update(from: tunnel?.activateOnDemandSetting())
            onDemandStatusObservervationToken = tunnel?.observe(\.isActivateOnDemandEnabled) { [weak self] tunnel, _ in
                self?.update(from: tunnel.activateOnDemandSetting())
            }
        }
    }

    var onDemandStatusObservervationToken: AnyObject?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        textLabel?.text = "Activate on demand"
        textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        textLabel?.adjustsFontForContentSizeCategory = true
        detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        detailTextLabel?.adjustsFontForContentSizeCategory = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(from activateOnDemandSetting: ActivateOnDemandSetting?) {
        detailTextLabel?.text = TunnelViewModel.activateOnDemandDetailText(for: activateOnDemandSetting)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        textLabel?.text = "Activate on demand"
        detailTextLabel?.text = ""
    }
}
