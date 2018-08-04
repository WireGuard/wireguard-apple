//
//  AppCoordinator.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 23-05-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import Foundation
import NetworkExtension
import KeychainSwift
import os.log

import CoreData
import BNRCoreDataStack

extension UINavigationController: Identifyable {}

let APPGROUP = "group.com.wireguard.ios.WireGuard"
let VPNBUNDLE = "com.wireguard.ios.WireGuard.WireGuardNetworkExtension"

class AppCoordinator: RootViewCoordinator {

    let persistentContainer = NSPersistentContainer(name: "WireGuard")
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    var currentManager: NETunnelProviderManager?

    // MARK: - Properties

    var childCoordinators: [Coordinator] = []

    var rootViewController: UIViewController {
        return self.tunnelsTableViewController
    }

    var status = NEVPNStatus.invalid {
        didSet {
            //TODO: signal status
            switch status {
            case .connected:
                os_log("Connected VPN", log: Log.general, type: .info)
            case .connecting, .disconnecting, .reasserting:
                os_log("Connecting VPN", log: Log.general, type: .info)
            case .disconnected, .invalid:
                os_log("Disconnecting VPN", log: Log.general, type: .info)
            }
        }
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
        reloadCurrentManager(nil)
    }

    // MARK: - Functions

    /// Starts the coordinator
    public func start() {
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

    func configureVPN(_ configure: @escaping (NETunnelProviderManager) -> NETunnelProviderProtocol?, completionHandler: @escaping (Error?) -> Void) {
        reloadCurrentManager { (error) in
            if let error = error {
                os_log("error reloading preferences: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                completionHandler(error)
                return
            }

            let manager = self.currentManager!
            if let protocolConfiguration = configure(manager) {
                manager.protocolConfiguration = protocolConfiguration
            }
            manager.isEnabled = true

            manager.saveToPreferences { (error) in
                if let error = error {
                    os_log("error saving preferences: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                    completionHandler(error)
                    return
                }
                os_log("saved preferences", log: Log.general, type: .info)
                self.reloadCurrentManager(completionHandler)
            }
        }
    }

    func reloadCurrentManager(_ completionHandler: ((Error?) -> Void)?) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
            if let error = error {
                completionHandler?(error)
                return
            }

            var manager: NETunnelProviderManager?

            for man in managers! {
                if let prot = man.protocolConfiguration as? NETunnelProviderProtocol {
                    if prot.providerBundleIdentifier == VPNBUNDLE {
                        manager = man
                        break
                    }
                }
            }

            if manager == nil {
                manager = NETunnelProviderManager()
            }

            self.currentManager = manager
            self.status = manager!.connection.status
            completionHandler?(nil)
        }
    }

    @objc private func VPNStatusDidChange(notification: NSNotification) {
        guard let status = currentManager?.connection.status else {
            os_log("VPNStatusDidChange", log: Log.general, type: .debug)
            return
        }
        os_log("VPNStatusDidChange: %{public}@", log: Log.general, type: .debug, description(for: status))
        self.status = status
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

    func connect(tunnel: Tunnel?, tunnelsTableViewController: TunnelsTableViewController) {
        let block = {
            switch self.status {
            case .invalid, .disconnected:
                self.connect(tunnel: tunnel)

            case .connected, .connecting:
                // TODO: this needs to check if the passed tunnel is the actual connected tunnel config
                self.disconnect()

            default:
                break
            }
        }

        if status == .invalid {
            reloadCurrentManager({ (_) in
                block()
            })
        } else {
            block()
        }
    }

    private func connect(tunnel: Tunnel?) {
        // TODO implement NETunnelProviderManager VC showing current connection status, pushing this config into VPN stack
        os_log("connect tunnel: %{public}@", log: Log.general, type: .info, tunnel?.description ?? "-none-")

        guard let tunnel = tunnel else {
            return
        }

        configureVPN({ (_) in
            //TODO: decide what to do with on demand
            //            self.currentManager?.isOnDemandEnabled = true
            self.currentManager?.onDemandRules = [NEOnDemandRuleConnect()]

            let protocolConfiguration = NETunnelProviderProtocol()
            let keychain = KeychainSwift()
            keychain.accessGroup = APPGROUP
            //TODO: Set secrets to keychain?

            protocolConfiguration.providerBundleIdentifier = VPNBUNDLE
            //TODO obtain endpoint hostname
//            protocolConfiguration.serverAddress = endpoint.hostname
            //TODO obtain endpoint username
//            protocolConfiguration.username = endpoint.username
            //TODO: how to obtain this?
//            protocolConfiguration.passwordReference = try? keychain.passwordReference(for: endpoint.username)
            protocolConfiguration.providerConfiguration = tunnel.generateProviderConfiguration()

            return protocolConfiguration
        }, completionHandler: { (error) in
            if let error = error {
                os_log("configure error: %{public}@", log: Log.general, type: .error, error.localizedDescription)
                return
            }
            let session = self.currentManager?.connection as! NETunnelProviderSession //swiftlint:disable:this force_cast
            do {
                try session.startTunnel()
            } catch let error {
                os_log("error starting tunnel: %{public}@", log: Log.general, type: .error, error.localizedDescription)
            }
        })
    }

    func disconnect() {
        configureVPN({ (_) in
            //TODO: decide what to do with on demand
            //            self.currentManager?.isOnDemandEnabled = false
            return nil
        }, completionHandler: { (_) in
            self.currentManager?.connection.stopVPNTunnel()
        })
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
        }
    }
}

extension AppCoordinator: TunnelConfigurationTableViewControllerDelegate {
    func didSave(tunnel: Tunnel, tunnelConfigurationTableViewController: TunnelConfigurationTableViewController) {
        navigationController.popToRootViewController(animated: true)
    }

}
