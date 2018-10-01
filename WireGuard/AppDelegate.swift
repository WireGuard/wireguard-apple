//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import UIKit
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        self.window = UIWindow(frame: UIScreen.main.bounds)
        appCoordinator = AppCoordinator(window: self.window!)
        appCoordinator.start()

        appCoordinator.checkAndCleanConfigs()

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
        defer {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                os_log("Failed to remove item from Inbox: %{public}@", log: Log.general, type: .error, url.absoluteString)
            }
        }
        if url.pathExtension == "conf" {
            do {
                try appCoordinator.importConfig(config: url)
            } catch {
                os_log("Unable to import config: %{public}@", log: Log.general, type: .error, url.absoluteString)
                return false
            }
            return true
        } else if url.pathExtension == "zip" {
            do {
                try appCoordinator.importConfigs(configZip: url)
            } catch {
                os_log("Unable to import config: %{public}@", log: Log.general, type: .error, url.absoluteString)
                return false
            }
            return true
        }
        return false

    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        appCoordinator.checkAndCleanConfigs()
    }
}
