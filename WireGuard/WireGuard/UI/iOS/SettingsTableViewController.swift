// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import UIKit
import os.log

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

    let tunnelsManager: TunnelsManager?

    init(tunnelsManager: TunnelsManager?) {
        self.tunnelsManager = tunnelsManager
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

    func exportConfigurationsAsZipFile(sourceView: UIView) {
        guard let tunnelsManager = tunnelsManager, tunnelsManager.numberOfTunnels() > 0 else {
            showErrorAlert(title: "Nothing to export", message: "There are no tunnel configurations to export")
            return
        }
        var inputsToArchiver: [(fileName: String, contents: Data)] = []
        var usedNames: Set<String> = []
        for i in 0 ..< tunnelsManager.numberOfTunnels() {
            guard let tunnelConfiguration = tunnelsManager.tunnel(at: i).tunnelConfiguration() else { continue }
            if let contents = WgQuickConfigFileWriter.writeConfigFile(from: tunnelConfiguration) {
                let name = tunnelConfiguration.interface.name
                var nameToCheck = name
                var i = 0
                while (usedNames.contains(nameToCheck)) {
                    i = i + 1
                    nameToCheck = "\(name)\(i)"
                }
                usedNames.insert(nameToCheck)
                inputsToArchiver.append((fileName: "\(nameToCheck).conf", contents: contents))
            }
        }

        // Based on file export code by Jeroen Leenarts <jeroen.leenarts@gmail.com> in commit ca35168
        guard let destinationDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let destinationURL = destinationDir.appendingPathComponent("wireguard-export.zip")
        do {
            try FileManager.default.removeItem(at: destinationURL)
        } catch {
            os_log("Failed to delete file: %{public}@ : %{public}@", log: OSLog.default, type: .error, destinationURL.absoluteString, error.localizedDescription)
        }

        var ok = false
        do {
            try ZipArchive.archive(inputs: inputsToArchiver, to: destinationURL)
            ok = true
        } catch {
            os_log("Failed to create archive: %{public}@ : %{public}@", log: OSLog.default, type: .error, destinationURL.absoluteString)
        }

        if (ok) {
            let activityVC = UIActivityViewController(activityItems: [destinationURL], applicationActivities: nil)
            // popoverPresentationController shall be non-nil on the iPad
            activityVC.popoverPresentationController?.sourceView = sourceView
            present(activityVC, animated: true)
        } else {
            showErrorAlert(title: "Could not export", message: "There was an error creating the tunnel configuration archive")
        }
    }

    func showErrorAlert(title: String, message: String) {
        let okAction = UIAlertAction(title: "Ok", style: .default)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)

        self.present(alert, animated: true, completion: nil)
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
            cell.onTapped = { [weak self] in
                self?.exportConfigurationsAsZipFile(sourceView: cell.button)
            }
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
