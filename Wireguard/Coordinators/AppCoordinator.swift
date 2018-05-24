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

class AppCoordinator: RootViewCoordinator {

    let persistentContainer = NSPersistentContainer(name: "WireGuard")
    let storyboard = UIStoryboard(name: "Main", bundle: nil)

    // MARK: - Properties

    var childCoordinators: [Coordinator] = []

    var rootViewController: UIViewController {
        return self.connectionsTableViewController
    }

    var connectionsTableViewController: ConnectionsTableViewController!

    /// Window to manage
    let window: UIWindow

    let navigationController: UINavigationController = {
        let navController = UINavigationController()
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
                    if let connectionsTableViewController = self?.storyboard.instantiateViewController(type: ConnectionsTableViewController.self) {
                        self?.connectionsTableViewController = connectionsTableViewController
                        self?.connectionsTableViewController.viewContext = self?.persistentContainer.viewContext
                        self?.connectionsTableViewController.delegate = self
                        self?.navigationController.viewControllers = [connectionsTableViewController]
                        do {
                            if let context = self?.persistentContainer.viewContext, try Profile.countInContext(context) == 0 {
                                print("No profiles ... yet")
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

extension AppCoordinator: ConnectionsTableViewControllerDelegate {
    func addProvider(connectionsTableViewController: ConnectionsTableViewController) {
        // TODO implement
    }

    func settings(connectionsTableViewController: ConnectionsTableViewController) {
        // TODO implement
    }

    func connect(profile: Profile) {
        // TODO implement
    }

    func delete(profile: Profile) {
        // TODO implement
    }
}
