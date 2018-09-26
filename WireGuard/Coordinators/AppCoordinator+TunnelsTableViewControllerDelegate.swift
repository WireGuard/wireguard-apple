//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import UIKit
import NetworkExtension
import os.log

import MobileCoreServices

import ZIPFoundation
import PromiseKit

extension AppCoordinator: TunnelsTableViewControllerDelegate {
    func status(for tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) -> NEVPNStatus {
        let session = self.providerManager(for: tunnel)?.connection as? NETunnelProviderSession
        return session?.status ?? .invalid
    }

    func addProvider(tunnelsTableViewController: TunnelsTableViewController) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Create from file or archive", comment: ""), style: .default) { [unowned self] _ in
            self.addProviderFromFile()
        })
        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Create from QR code", comment: ""), style: .default) { [unowned self] _ in
            self.addProviderWithQRScan()
        })
        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Create from scratch", comment: ""), style: .default) { [unowned self] _ in
            self.addProviderManually()
        })
        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))

        tunnelsTableViewController.present(actionSheet, animated: true, completion: nil)
    }

    func addProviderFromFile() {
        let documentPickerController = UIDocumentPickerViewController(documentTypes: [String(kUTTypeZipArchive), "com.wireguard.config.quick"], in: .import)
        documentPickerController.delegate = documentPickerDelegateObject
        tunnelsTableViewController.present(documentPickerController, animated: true, completion: nil)
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
        _ = refreshProviderManagers().then { () -> Promise<Void> in
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

            return Promise.value(())
        }
    }

    func disconnect(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) {
        _ = refreshProviderManagers().then { () -> Promise<Void> in
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
            return Promise.value(())
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

    func info(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) {
        print("info tunnel \(tunnel)")

        showTunnelInfoViewController(tunnel: tunnel, context: self.persistentContainer.viewContext)
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
                self.providerManagers?.removeAll { $0 == manager }
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

    func saveTunnel(_ tunnel: Tunnel) {
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

        manager.saveToPreferences { (error) in
            if let error = error {
                os_log("error saving preferences: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                return
            }
            os_log("saved preferences", log: Log.general, type: .info)
        }

        _ = refreshProviderManagers().then { () -> Promise<Void> in
            self.navigationController.popViewController(animated: true)
            return Promise.value(())
        }
    }
}
