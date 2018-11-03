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
        [.exportZipArchive],
        [.iosAppVersion, .goBackendVersion]
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

        let wireguardCaptionedImage = UIImage(named: "wireguard.pdf", in: Bundle.main, compatibleWith: nil)!
        let wireguardCaptionedImageView = UIImageView(image: wireguardCaptionedImage)
        wireguardCaptionedImageView.contentMode = .scaleAspectFit
        let wireguardCaptionedImageContainerView = UIView()
        wireguardCaptionedImageContainerView.addSubview(wireguardCaptionedImageView)
        wireguardCaptionedImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            wireguardCaptionedImageView.topAnchor.constraint(equalTo: wireguardCaptionedImageContainerView.layoutMarginsGuide.topAnchor),
            wireguardCaptionedImageView.bottomAnchor.constraint(equalTo: wireguardCaptionedImageContainerView.layoutMarginsGuide.bottomAnchor),
            wireguardCaptionedImageView.leftAnchor.constraint(equalTo: wireguardCaptionedImageContainerView.layoutMarginsGuide.leftAnchor),
            wireguardCaptionedImageView.rightAnchor.constraint(equalTo: wireguardCaptionedImageContainerView.layoutMarginsGuide.rightAnchor),
            ])
        self.wireguardCaptionedImage = (view: wireguardCaptionedImageContainerView, size: wireguardCaptionedImage.size)
    }

    @objc func doneTapped() {
        dismiss(animated: true, completion: nil)
    }

    func exportConfigurationsAsZipFile(sourceView: UIView) {
        guard let tunnelsManager = tunnelsManager, tunnelsManager.numberOfTunnels() > 0 else {
            showErrorAlert(title: "Nothing to export", message: "There are no tunnels to export")
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

        guard let destinationDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let destinationURL = destinationDir.appendingPathComponent("wireguard-export.zip")
        do {
            try FileManager.default.removeItem(at: destinationURL)
        } catch {
            os_log("Failed to delete file: %{public}@ : %{public}@", log: OSLog.default, type: .error, destinationURL.absoluteString, error.localizedDescription)
        }

        do {
            try ZipArchive.archive(inputs: inputsToArchiver, to: destinationURL)
            let activityVC = UIActivityViewController(activityItems: [destinationURL], applicationActivities: nil)
            // popoverPresentationController shall be non-nil on the iPad
            activityVC.popoverPresentationController?.sourceView = sourceView
            present(activityVC, animated: true)

        } catch (let error) {
            showErrorAlert(title: "Unable to export", message: "There was an error exporting the tunnel configuration archive: \(String(describing: error))")
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
            return "Export configurations"
        case 1:
            return "About"
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

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard (section == 1) else { return nil }
        return self.wireguardCaptionedImage?.view
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard (section == 1) else { return 0 }
        guard let imageSize = self.wireguardCaptionedImage?.size else { return 0 }
        return min(tableView.rowHeight * 1.5, (tableView.bounds.width / imageSize.width) * imageSize.height)
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
    var onTapped: (() -> Void)?

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
