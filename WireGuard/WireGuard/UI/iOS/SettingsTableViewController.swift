// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import UIKit

class SettingsTableViewController: UITableViewController {

    enum SettingsFields: String {
        case iosAppVersion = "WireGuard for iOS"
        case goBackendVersion = "WireGuard Go Backend"
        case exportZipArchive = "Export zip archive"
    }

    let settingsFieldsBySection : [[SettingsFields]] = [
        [.iosAppVersion, .goBackendVersion],
        [.exportZipArchive]
    ]

    init() {
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Settings"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))

        self.tableView.rowHeight = 44
        self.tableView.allowsSelection = false

        self.tableView.register(TunnelSettingsTableViewKeyValueCell.self, forCellReuseIdentifier: TunnelSettingsTableViewKeyValueCell.id)
        self.tableView.register(TunnelSettingsTableViewButtonCell.self, forCellReuseIdentifier: TunnelSettingsTableViewButtonCell.id)
    }

    @objc func doneTapped() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: UITableViewDataSource

extension SettingsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return settingsFieldsBySection.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsFieldsBySection[section].count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch (section) {
        case 0:
            return "About"
        case 1:
            return "Export configurations"
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let field = settingsFieldsBySection[indexPath.section][indexPath.row]
        if (field == .iosAppVersion || field == .goBackendVersion) {
            let cell = tableView.dequeueReusableCell(withIdentifier: TunnelSettingsTableViewKeyValueCell.id, for: indexPath) as! TunnelSettingsTableViewKeyValueCell
            cell.key = field.rawValue
            if (field == .iosAppVersion) {
                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
                cell.value = appVersion
            } else if (field == .goBackendVersion) {
                cell.value = "TODO"
            }
            return cell
        } else {
            assert(field == .exportZipArchive)
            let cell = tableView.dequeueReusableCell(withIdentifier: TunnelSettingsTableViewButtonCell.id, for: indexPath) as! TunnelSettingsTableViewButtonCell
            cell.buttonText = field.rawValue
            return cell
        }
    }
}

class TunnelSettingsTableViewKeyValueCell: UITableViewCell {
    static let id: String = "TunnelSettingsTableViewKeyValueCell"
    var key: String {
        get { return textLabel?.text ?? "" }
        set(value) { textLabel?.text = value }
    }
    var value: String {
        get { return detailTextLabel?.text ?? "" }
        set(value) { detailTextLabel?.text = value }
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: TunnelSettingsTableViewKeyValueCell.id)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        key = ""
        value = ""
    }
}

class TunnelSettingsTableViewButtonCell: UITableViewCell {
    static let id: String = "TunnelSettingsTableViewButtonCell"
    var buttonText: String {
        get { return button.title(for: .normal) ?? "" }
        set(value) { button.setTitle(value, for: .normal) }
    }
    var onTapped: (() -> Void)? = nil

    let button: UIButton

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        button = UIButton(type: .system)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
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
    }
}
