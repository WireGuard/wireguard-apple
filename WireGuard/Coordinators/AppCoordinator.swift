//
//  AppCoordinator.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 23-05-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import Foundation
import NetworkExtension
import os.log
import ZIPFoundation

import CoreData
import BNRCoreDataStack

enum AppCoordinatorError: Error {
    case configImportError(msg: String)
}

extension UINavigationController: Identifyable {}

let APPGROUP = "group.com.wireguard.ios.WireGuard"
let VPNBUNDLE = "com.wireguard.ios.WireGuard.WireGuardNetworkExtension"

class AppCoordinator: RootViewCoordinator {

    let persistentContainer = NSPersistentContainer(name: "WireGuard")
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    var providerManagers: [NETunnelProviderManager]?

    // MARK: - Properties

    var childCoordinators: [Coordinator] = []

    var rootViewController: UIViewController {
        return self.tunnelsTableViewController
    }

    var tunnelsTableViewController: TunnelsTableViewController!

    /// Window to manage
    let window: UIWindow

    let navigationController: UINavigationController = {
        let navController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(type: UINavigationController.self)
        return navController
    }()

    // MARK: - Init
    public init(window: UIWindow) {
        self.window = window

        self.window.rootViewController = self.navigationController
        self.window.makeKeyAndVisible()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(VPNStatusDidChange(notification:)),
                                               name: .NEVPNStatusDidChange,
                                               object: nil)
    }

    // MARK: - Functions

    /// Starts the coordinator
    public func start() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            if let error = error {
                os_log("Unable to load provider managers: %{public}@", log: Log.general, type: .error, error.localizedDescription)
            }
            self?.providerManagers = managers
        }

        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.loadPersistentStores { [weak self] (_, error) in
            if let error = error {
                print("Unable to Load Persistent Store. \(error), \(error.localizedDescription)")

            } else {
                DispatchQueue.main.async {
                    //start
                    if let tunnelsTableViewController = self?.storyboard.instantiateViewController(type: TunnelsTableViewController.self) {
                        self?.tunnelsTableViewController = tunnelsTableViewController
                        self?.tunnelsTableViewController.viewContext = self?.persistentContainer.viewContext
                        self?.tunnelsTableViewController.delegate = self
                        self?.navigationController.viewControllers = [tunnelsTableViewController]
                        do {
                            if let context = self?.persistentContainer.viewContext, try Tunnel.countInContext(context) == 0 {
                                print("No tunnels ... yet")
                            }
                        } catch {
                            self?.showError(error)
                        }
                    }
                }
            }
        }
    }

    func importConfig(config: URL) throws {
        do {
            try importConfig(configString: try String(contentsOf: config), title: config.deletingPathExtension().lastPathComponent)
        } catch {
            throw AppCoordinatorError.configImportError(msg: "Failed")
        }
    }

    func importConfig(configString: String, title: String) throws {
        do {
            let addContext = persistentContainer.newBackgroundContext()
            let tunnel = try Tunnel.fromConfig(configString, context: addContext)
            tunnel.title = title
            addContext.saveContext()
            self.saveTunnel(tunnel)
        } catch {
            throw AppCoordinatorError.configImportError(msg: "Failed")
        }
    }

    func importConfigs(configZip: URL) throws {
        if let archive = Archive(url: configZip, accessMode: .read) {
            for entry in archive {
                var entryData = Data(capacity: 0)
                _ = try archive.extract(entry) { (data) in
                    entryData.append(data)
                }
                if let config = String(data: entryData, encoding: .utf8) {
                    try importConfig(configString: config, title: entry.path)
                }
            }
        }
    }

    // swiftlint:disable next function_body_length
    func exportConfigs(barButtonItem: UIBarButtonItem) {
        guard let path = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
        }
        let saveFileURL = path.appendingPathComponent("wireguard-export.zip")
        do {
            try FileManager.default.removeItem(at: saveFileURL)
        } catch {
            os_log("Failed to delete file: %{public}@ : %{public}@", log: Log.general, type: .error, saveFileURL.absoluteString, error.localizedDescription)
        }

        guard let archive = Archive(url: saveFileURL, accessMode: .create) else {
            return
        }

        do {
            var tunnelsByTitle = [String: [Tunnel]]()
            let tunnels = try Tunnel.allInContext(persistentContainer.viewContext)
            tunnels.forEach {
                guard let title = $0.title ?? $0.tunnelIdentifier else {
                    // there is always a tunnelidentifier.
                    return
                }
                if let tunnels = tunnelsByTitle[title] {
                    tunnelsByTitle[title] = tunnels + [$0]
                } else {
                    tunnelsByTitle[title] = [$0]
                }
            }

            func addEntry(title: String, tunnel: Tunnel) throws {
                let data = tunnel.export().data(using: .utf8)!
                let byteCount: UInt32 = UInt32(data.count)
                try archive.addEntry(with: "\(title).conf", type: .file, uncompressedSize: byteCount, provider: { (position, size) -> Data in
                    return data.subdata(in: position ..< size)
                })
            }

            try tunnelsByTitle.keys.forEach {
                if let tunnels = tunnelsByTitle[$0] {
                    if tunnels.count == 1 {
                        try addEntry(title: $0, tunnel: tunnels[0])
                    } else {
                        for (index, tunnel) in tunnels.enumerated() {
                            try addEntry(title: $0 + "-\(index + 1)", tunnel: tunnel)
                        }
                    }
                }
            }
        } catch {
            os_log("Failed to create archive file: %{public}@ : %{public}@", log: Log.general, type: .error, saveFileURL.absoluteString, error.localizedDescription)
            return
        }

        let activityViewController = UIActivityViewController(
            activityItems: [saveFileURL],
            applicationActivities: nil)
        if let popoverPresentationController = activityViewController.popoverPresentationController {
            popoverPresentationController.barButtonItem = barButtonItem
        }
        navigationController.present(activityViewController, animated: true) {
        }
    }

    func exportConfig(tunnel: Tunnel, barButtonItem: UIBarButtonItem) {
        let exportString = tunnel.export()

        guard let path = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
        }
        let saveFileURL = path.appendingPathComponent("/\(tunnel.title ?? "wireguard").conf")
        do {
            try exportString.write(to: saveFileURL, atomically: true, encoding: .utf8)
        } catch {
            os_log("Failed to export tunnelto: %{public}@", log: Log.general, type: .error, saveFileURL.absoluteString)
            return
        }

        let activityViewController = UIActivityViewController(
            activityItems: [saveFileURL],
            applicationActivities: nil)
        if let popoverPresentationController = activityViewController.popoverPresentationController {
            popoverPresentationController.barButtonItem = barButtonItem
        }
        self.navigationController.present(activityViewController, animated: true) {
        }
    }

    // MARK: - NEVPNManager handling

    @objc private func VPNStatusDidChange(notification: NSNotification) {
        guard let session = notification.object as? NETunnelProviderSession else {
            return
        }

        guard let prot = session.manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return
        }

        guard let changedTunnelIdentifier = prot.providerConfiguration?[PCKeys.tunnelIdentifier.rawValue] as? String else {
            return
        }

        providerManagers?.first(where: { (manager) -> Bool in
            guard let prot = manager.protocolConfiguration as? NETunnelProviderProtocol else {
                return false
            }
            guard let candidateTunnelIdentifier = prot.providerConfiguration?[PCKeys.tunnelIdentifier.rawValue] as? String else {
                return false
            }

            return changedTunnelIdentifier == candidateTunnelIdentifier

        })?.loadFromPreferences(completionHandler: { [weak self] (_) in
            self?.tunnelsTableViewController.updateStatus(for: changedTunnelIdentifier)
        })
    }

    public func showError(_ error: Error) {
        showAlert(title: NSLocalizedString("Error", comment: "Error alert title"), message: error.localizedDescription)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK button"), style: .default))
        self.navigationController.present(alert, animated: true)
    }

    private func description(for status: NEVPNStatus) -> String {
        switch status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        case .disconnecting:
            return "Disconnecting"
        case .invalid:
            return "Invalid"
        case .reasserting:
            return "Reasserting"
        }
    }
}

extension AppCoordinator: TunnelsTableViewControllerDelegate {
    func exportTunnels(tunnelsTableViewController: TunnelsTableViewController, barButtonItem: UIBarButtonItem) {
        self.exportConfigs(barButtonItem: barButtonItem)
    }

    func status(for tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) -> NEVPNStatus {
        let session = self.providerManager(for: tunnel)?.connection as? NETunnelProviderSession
        return session?.status ?? .invalid
    }

    func addProvider(tunnelsTableViewController: TunnelsTableViewController) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Add Manually", style: .default) { [unowned self] _ in
            self.addProviderManually()
        })
        actionSheet.addAction(UIAlertAction(title: "Scan QR Code", style: .default) { [unowned self] _ in
            self.addProviderWithQRScan()
        })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        tunnelsTableViewController.present(actionSheet, animated: true, completion: nil)
    }

    func addProviderManually() {
        let addContext = persistentContainer.newBackgroundContext()
        showTunnelConfigurationViewController(tunnel: nil, context: addContext)
    }

    func addProviderWithQRScan() {
        let addContext = persistentContainer.newBackgroundContext()

        let qrScanViewController = storyboard.instantiateViewController(type: QRScanViewController.self)

        qrScanViewController.configure(context: addContext, delegate: self)

        self.navigationController.pushViewController(qrScanViewController, animated: true)
    }

    func connect(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) {
        let manager = self.providerManager(for: tunnel)!
        let block = {
            switch manager.connection.status {
            case .invalid, .disconnected:
                self.connect(tunnel: tunnel)
            default:
                break
            }
        }

        if manager.connection.status == .invalid {
            manager.loadFromPreferences { (_) in
                block()
            }
        } else {
            block()
        }
    }

    func disconnect(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) {
        let manager = self.providerManager(for: tunnel)!
        let block = {
            switch manager.connection.status {
            case .connected, .connecting:
                self.disconnect(tunnel: tunnel)
            default:
                break
            }
        }

        if manager.connection.status == .invalid {
            manager.loadFromPreferences { (_) in
                block()
            }
        } else {
            block()
        }
    }

    private func connect(tunnel: Tunnel) {
        os_log("connect tunnel: %{public}@", log: Log.general, type: .info, tunnel.description)
        // Should the manager be enabled?

        let manager = providerManager(for: tunnel)
        manager?.isEnabled = true
        manager?.saveToPreferences { (error) in
            if let error = error {
                os_log("error saving preferences: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                return
            }
            os_log("saved preferences", log: Log.general, type: .info)

            let session = manager?.connection as! NETunnelProviderSession //swiftlint:disable:this force_cast
            do {
                try session.startTunnel()
            } catch let error {
                os_log("error starting tunnel: %{public}@", log: Log.general, type: .error, error.localizedDescription)
            }
        }
    }

    func disconnect(tunnel: Tunnel) {
        let manager = providerManager(for: tunnel)
        manager?.connection.stopVPNTunnel()
    }

    func configure(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) {
        print("configure tunnel \(tunnel)")
        let editContext = persistentContainer.newBackgroundContext()
        var backgroundTunnel: Tunnel?
        editContext.performAndWait {
            backgroundTunnel = editContext.object(with: tunnel.objectID) as? Tunnel
        }

        showTunnelConfigurationViewController(tunnel: backgroundTunnel, context: editContext)
    }

    func showTunnelConfigurationViewController(tunnel: Tunnel?, context: NSManagedObjectContext) {
        let tunnelConfigurationViewController = storyboard.instantiateViewController(type: TunnelConfigurationTableViewController.self)

        tunnelConfigurationViewController.configure(context: context, delegate: self, tunnel: tunnel)

        self.navigationController.pushViewController(tunnelConfigurationViewController, animated: true)
    }

    func delete(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) {
        print("delete tunnel \(tunnel)")

        if let moc = tunnel.managedObjectContext {
            moc.perform {
                moc.delete(tunnel)
                moc.saveContextToStore()
            }
            let manager = providerManager(for: tunnel)
            manager?.removeFromPreferences { (error) in
                if let error = error {
                    os_log("error removing preferences: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                    return
                }
                os_log("removed preferences", log: Log.general, type: .info)
            }
        }
    }

    private func providerManager(for tunnel: Tunnel) -> NETunnelProviderManager? {
        return self.providerManagers?.first {
            guard let prot = $0.protocolConfiguration as? NETunnelProviderProtocol else {
                return false
            }
            guard let tunnelIdentifier = prot.providerConfiguration?[PCKeys.tunnelIdentifier.rawValue] as? String else {
                return false
            }
            return tunnelIdentifier == tunnel.tunnelIdentifier
        }
    }

    private func saveTunnel(_ tunnel: Tunnel) {
        let manager = providerManager(for: tunnel) ?? NETunnelProviderManager()
        manager.localizedDescription = tunnel.title

        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = VPNBUNDLE
        protocolConfiguration.serverAddress = (tunnel.peers?.array as? [Peer])?.compactMap { $0.endpoint}.joined(separator: ", ")
        protocolConfiguration.providerConfiguration = tunnel.generateProviderConfiguration()

        manager.protocolConfiguration = protocolConfiguration
        let connectRule = NEOnDemandRuleConnect()
        connectRule.interfaceTypeMatch = .any
        manager.onDemandRules = [connectRule]
//        manager.isOnDemandEnabled = true

        manager.saveToPreferences { (error) in
            if let error = error {
                os_log("error saving preferences: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                return
            }
            os_log("saved preferences", log: Log.general, type: .info)
        }

        navigationController.popToRootViewController(animated: true)
    }
}

extension AppCoordinator: TunnelConfigurationTableViewControllerDelegate {
    func export(tunnel: Tunnel, barButtonItem: UIBarButtonItem) {
        exportConfig(tunnel: tunnel, barButtonItem: barButtonItem)
    }

    func didSave(tunnel: Tunnel, tunnelConfigurationTableViewController: TunnelConfigurationTableViewController) {
        saveTunnel(tunnel)
    }

}

extension AppCoordinator: QRScanViewControllerDelegate {
    func didSave(tunnel: Tunnel, qrScanViewController: QRScanViewController) {
        showTunnelConfigurationViewController(tunnel: tunnel, context: tunnel.managedObjectContext!)
    }

}
