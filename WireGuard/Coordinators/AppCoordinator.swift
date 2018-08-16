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

import CoreData
import BNRCoreDataStack

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

    // MARK: - NEVPNManager handling

    @objc private func VPNStatusDidChange(notification: NSNotification) {
        //TODO implement
        guard let session = notification.object as? NETunnelProviderSession else {
            return
        }

        os_log("VPNStatusDidChange: %{public}@", log: Log.general, type: .debug, description(for: session.status))
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
    func addProvider(tunnelsTableViewController: TunnelsTableViewController) {
        let addContext = persistentContainer.newBackgroundContext()
        showTunnelConfigurationViewController(tunnel: nil, context: addContext)
    }

    func connect(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) {
        let manager = self.providerManager(for: tunnel)!
        let block = {
            switch manager.connection.status {
            case .invalid, .disconnected:
                self.connect(tunnel: tunnel)

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
            guard let tunnelIdentifier = prot.providerConfiguration?["tunnelIdentifier"] as? String else {
                return false
            }
            return tunnelIdentifier == tunnel.tunnelIdentifier
        }
    }
}

extension AppCoordinator: TunnelConfigurationTableViewControllerDelegate {
    func didSave(tunnel: Tunnel, tunnelConfigurationTableViewController: TunnelConfigurationTableViewController) {
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
