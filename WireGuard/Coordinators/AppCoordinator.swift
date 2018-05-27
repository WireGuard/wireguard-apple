//
//  AppCoordinator.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 23-05-18.
//  Copyright © 2018 WireGuard. All rights reserved.
//

import Foundation

import CoreData
import BNRCoreDataStack

extension UINavigationController: Identifyable {}

class AppCoordinator: RootViewCoordinator {

    let persistentContainer = NSPersistentContainer(name: "WireGuard")
    let storyboard = UIStoryboard(name: "Main", bundle: nil)

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

    public func showError(_ error: Error) {
        showAlert(title: NSLocalizedString("Error", comment: "Error alert title"), message: error.localizedDescription)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK button"), style: .default))
        self.navigationController.present(alert, animated: true)
    }
}

extension AppCoordinator: TunnelsTableViewControllerDelegate {
    func addProvider(tunnelsTableViewController: TunnelsTableViewController) {
        let addContext = persistentContainer.newBackgroundContext()
        showTunnelConfigurationViewController(tunnel: nil, context: addContext)
    }

    func connect(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) {
        // TODO implement
        print("connect tunnel \(tunnel)")
    }

    func configure(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) {
        // TODO implement
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
        // TODO implement
        print("delete tunnel \(tunnel)")
    }
}

extension AppCoordinator: TunnelConfigurationTableViewControllerDelegate {
    func didSave(tunnel: Tunnel, tunnelConfigurationTableViewController: TunnelConfigurationTableViewController) {
        navigationController.popToRootViewController(animated: true)
    }

}
