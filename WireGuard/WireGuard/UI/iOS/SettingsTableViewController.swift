// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit
import os.log

class SettingsTableViewController: UITableViewController {

    enum SettingsFields: String {
        case iosAppVersion = "WireGuard for iOS"
        case goBackendVersion = "WireGuard Go Backend"
        case exportZipArchive = "Export zip archive"
    }

    let settingsFieldsBySection: [[SettingsFields]] = [
        [.iosAppVersion, .goBackendVersion],
        [.exportZipArchive]
    ]

    let tunnelsManager: TunnelsManager?
    var wireguardCaptionedImage: (view: UIView, size: CGSize)?

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

        let logo = UIImageView(image: UIImage(named: "wireguard.pdf", in: Bundle.main, compatibleWith: nil)!)
        logo.contentMode = .scaleAspectFit
        let height = self.tableView.rowHeight * 1.5
        let width = height * logo.image!.size.width / logo.image!.size.height
        logo.frame = CGRect(x: 0, y: 0, width: width, height: height)
        logo.bounds = logo.frame.insetBy(dx: 2, dy: 2)
        self.tableView.tableFooterView = logo
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let logo = self.tableView.tableFooterView else { return }
        let bottomPadding = max(self.tableView.layoutMargins.bottom, CGFloat(10))
        let fullHeight = max(self.tableView.contentSize.height, self.tableView.bounds.size.height - self.tableView.layoutMargins.top - bottomPadding)
        let e = logo.frame
        logo.frame = CGRect(x: e.minX, y: fullHeight - e.height, width: e.width, height: e.height)
    }

    @objc func doneTapped() {
        dismiss(animated: true, completion: nil)
    }

    func exportConfigurationsAsZipFile(sourceView: UIView) {
        guard let tunnelsManager = tunnelsManager else { return }
        guard let destinationDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let destinationURL = destinationDir.appendingPathComponent("wireguard-export.zip")
        do {
            try FileManager.default.removeItem(at: destinationURL)
        } catch {
            os_log("Failed to delete file: %{public}@ : %{public}@", log: OSLog.default, type: .error, destinationURL.absoluteString, error.localizedDescription)
        }

        let count = tunnelsManager.numberOfTunnels()
        let tunnelConfigurations = (0 ..< count).compactMap { tunnelsManager.tunnel(at: $0).tunnelConfiguration() }
        ZipExporter.exportConfigFiles(tunnelConfigurations: tunnelConfigurations, to: destinationURL) { [weak self] (error) in
            if let error = error {
                ErrorPresenter.showErrorAlert(error: error, from: self)
                return
            }
            let activityVC = UIActivityViewController(activityItems: [destinationURL], applicationActivities: nil)
            // popoverPresentationController shall be non-nil on the iPad
            activityVC.popoverPresentationController?.sourceView = sourceView
            activityVC.popoverPresentationController?.sourceRect = sourceView.bounds
            self?.present(activityVC, animated: true)
        }
    }

    func showErrorAlert(title: String, message: String) {
        let okAction = UIAlertAction(title: "OK", style: .default)
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
                var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
                if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    appVersion += " (\(appBuild))"
                }
                cell.value = appVersion
            } else if (field == .goBackendVersion) {
                cell.value = WIREGUARD_GO_VERSION
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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
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
    var onTapped: (() -> Void)?

    let button: UIButton

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
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
