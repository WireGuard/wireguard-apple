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
        connect(tunnel: tunnel)
    }

    func disconnect(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) {
        disconnect(tunnel: tunnel)
    }

    func info(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) {
        showTunnelInfoViewController(tunnel: tunnel, context: self.persistentContainer.viewContext)
    }

    func delete(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) {
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
