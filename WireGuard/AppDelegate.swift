//
//  AppDelegate.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 23-05-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import UIKit
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.appCoordinator = AppCoordinator(window: self.window!)
        self.appCoordinator.start()

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
        guard url.pathExtension == "conf" else { return false }

        do {
            try appCoordinator.importConfig(config: url)
        } catch {
            os_log("Unable to import config: %{public}@", log: Log.general, type: .error, url.absoluteString)
            return false
        }
        return true
    }
}
