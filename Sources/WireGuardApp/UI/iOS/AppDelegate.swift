// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import UIKit
import os.log
import Intents
import AppIntents

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var mainVC: MainViewController?
    var isLaunchedForSpecificAction = false

    var tunnelsManager: TunnelsManager?

    static let tunnelsManagerReadyNotificationName: Notification.Name = Notification.Name(rawValue: "com.wireguard.ios.tunnelsManagerReadyNotification")

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Logger.configureGlobal(tagged: "APP", withFilePath: FileManager.logFileURL?.path)

        if let launchOptions = launchOptions {
            if launchOptions[.url] != nil || launchOptions[.shortcutItem] != nil {
                isLaunchedForSpecificAction = true
            }
        }

        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window

        let mainVC = MainViewController()
        window.rootViewController = mainVC
        window.makeKeyAndVisible()

        self.mainVC = mainVC

        // Create the tunnels manager, and when it's ready, inform tunnelsListVC
        TunnelsManager.create { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                ErrorPresenter.showErrorAlert(error: error, from: self.mainVC)
            case .success(let tunnelsManager):
                self.tunnelsManager = tunnelsManager
                self.mainVC?.tunnelsListVC?.setTunnelsManager(tunnelsManager: tunnelsManager)

                tunnelsManager.activationDelegate = self.mainVC

                if #available(iOS 16.0, *) {
                    AppDependencyManager.shared.add(dependency: tunnelsManager)
                }

                NotificationCenter.default.post(name: AppDelegate.tunnelsManagerReadyNotificationName,
                                                object: self,
                                                userInfo: nil)
            }
        }

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        mainVC?.importFromDisposableFile(url: url)
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        mainVC?.refreshTunnelConnectionStatuses()
    }

    func applicationWillResignActive(_ application: UIApplication) {
        guard let allTunnelNames = mainVC?.allTunnelNames() else { return }
        application.shortcutItems = QuickActionItem.createItems(allTunnelNames: allTunnelNames)
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        guard shortcutItem.type == QuickActionItem.type else {
            completionHandler(false)
            return
        }
        let tunnelName = shortcutItem.localizedTitle
        mainVC?.showTunnelDetailForTunnel(named: tunnelName, animated: false, shouldToggleStatus: true)
        completionHandler(true)
    }
}

extension AppDelegate {
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return true
    }

    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        return !self.isLaunchedForSpecificAction
    }

    func application(_ application: UIApplication, viewControllerWithRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        guard let vcIdentifier = identifierComponents.last else { return nil }
        if vcIdentifier.hasPrefix("TunnelDetailVC:") {
            let tunnelName = String(vcIdentifier.suffix(vcIdentifier.count - "TunnelDetailVC:".count))
            if let tunnelsManager = mainVC?.tunnelsManager {
                if let tunnel = tunnelsManager.tunnel(named: tunnelName) {
                    return TunnelDetailTableViewController(tunnelsManager: tunnelsManager, tunnel: tunnel)
                }
            } else {
                // Show it when tunnelsManager is available
                mainVC?.showTunnelDetailForTunnel(named: tunnelName, animated: false, shouldToggleStatus: false)
            }
        }
        return nil
    }
}

extension AppDelegate {

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

        guard let interaction = userActivity.interaction else {
            return false
        }

        if interaction.intent is UpdateConfigurationIntent {
            if let tunnelsManager = tunnelsManager {
                self.handleupdateConfigurationIntent(interaction: interaction, tunnelsManager: tunnelsManager)
            } else {
                var token: NSObjectProtocol?
                token = NotificationCenter.default.addObserver(forName: AppDelegate.tunnelsManagerReadyNotificationName, object: nil, queue: .main) { [weak self] _ in
                    guard let tunnelsManager = self?.tunnelsManager else { return }

                    self?.handleupdateConfigurationIntent(interaction: interaction, tunnelsManager: tunnelsManager)
                    NotificationCenter.default.removeObserver(token!)
                }
            }

            return true
        }

        return false
    }

    func handleupdateConfigurationIntent(interaction: INInteraction, tunnelsManager: TunnelsManager) {

        guard let updateConfigurationIntent = interaction.intent as? UpdateConfigurationIntent,
              let configurationUpdates = interaction.intentResponse?.userActivity?.userInfo else {
            return
        }

        guard let tunnelName = updateConfigurationIntent.tunnel,
              let configurations = configurationUpdates["Configuration"] as? [String: [String: String]] else {
                  wg_log(.error, message: "Failed to get informations to update the configuration")
                  return
        }

        guard let tunnel = tunnelsManager.tunnel(named: tunnelName),
              let tunnelConfiguration = tunnel.tunnelConfiguration else {
                  wg_log(.error, message: "Failed to get tunnel configuration with name \(tunnelName)")
                  ErrorPresenter.showErrorAlert(title: "Tunnel not found",
                                                message: "Tunnel with name '\(tunnelName)' is not present.",
                                                from: self.mainVC)
                  return
        }

        var peers = tunnelConfiguration.peers

        for (peerPubKey, valuesToUpdate) in configurations {
            guard let peerIndex = peers.firstIndex(where: { $0.publicKey.base64Key == peerPubKey }) else {
                wg_log(.debug, message: "Failed to find peer \(peerPubKey) in tunnel with name \(tunnelName)")
                ErrorPresenter.showErrorAlert(title: "Peer not found",
                                              message: "Peer '\(peerPubKey)' is not present in '\(tunnelName)' tunnel.",
                                              from: self.mainVC)
                continue
            }

            if let endpointString = valuesToUpdate["Endpoint"] {
                if let newEntpoint = Endpoint(from: endpointString) {
                    peers[peerIndex].endpoint = newEntpoint
                } else {
                    wg_log(.debug, message: "Failed to convert \(endpointString) to Endpoint")
                }
            }
        }

        let newConfiguration = TunnelConfiguration(name: tunnel.name, interface: tunnelConfiguration.interface, peers: peers)

        tunnelsManager.modify(tunnel: tunnel, tunnelConfiguration: newConfiguration, onDemandOption: tunnel.onDemandOption) { error in
            guard error == nil else {
                wg_log(.error, message: error!.localizedDescription)
                ErrorPresenter.showErrorAlert(error: error!, from: self.mainVC)
                return
            }

            if let completionUrlString = updateConfigurationIntent.completionUrl,
                !completionUrlString.isEmpty,
                let completionUrl = URL(string: completionUrlString) {
                UIApplication.shared.open(completionUrl, options: [:], completionHandler: nil)
            }

            wg_log(.debug, message: "Updated configuration of tunnel \(tunnelName)")
        }
    }
}
