// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var mainVC: MainViewController?

    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        if let appLogFilePath = FileManager.appLogFileURL?.path {
            if !Logger.configure(withFilePath: appLogFilePath) {
                os_log("Can't open log file for writing. Log is not saved to file.", log: OSLog.default, type: .error)
            }
        } else {
            os_log("Can't obtain log file URL. Log is not saved to file.", log: OSLog.default, type: .error)
        }

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = UIColor.white
        self.window = window

        let mainVC = MainViewController()
        window.rootViewController = mainVC
        window.makeKeyAndVisible()

        self.mainVC = mainVC

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        mainVC?.tunnelsListVC?.importFromFile(url: url) {
            _ = FileManager.deleteFile(at: url)
        }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        mainVC?.refreshTunnelConnectionStatuses()
    }
}

// MARK: State restoration

extension AppDelegate {
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return true
    }

    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        return true
    }

    func application(_ application: UIApplication,
                     viewControllerWithRestorationIdentifierPath identifierComponents: [String],
                     coder: NSCoder) -> UIViewController? {
        guard let vcIdentifier = identifierComponents.last else { return nil }
        if vcIdentifier.hasPrefix("TunnelDetailVC:") {
            let tunnelName = String(vcIdentifier.suffix(vcIdentifier.count - "TunnelDetailVC:".count))
            if let tunnelsManager = mainVC?.tunnelsManager {
                if let tunnel = tunnelsManager.tunnel(named: tunnelName) {
                    return TunnelDetailTableViewController(tunnelsManager: tunnelsManager, tunnel: tunnel)
                }
            } else {
                // Show it when tunnelsManager is available
                mainVC?.showTunnelDetailForTunnel(named: tunnelName, animated: false)
            }
        }
        return nil
    }
}
