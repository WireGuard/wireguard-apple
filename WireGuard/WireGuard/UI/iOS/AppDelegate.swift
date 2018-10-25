// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import UIKit
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var mainVC: MainViewController?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = UIColor.white
        self.window = window

        let mainVC = MainViewController()
        window.rootViewController = mainVC
        window.makeKeyAndVisible()

        self.mainVC = mainVC

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        // Based on importing code by Jeroen Leenarts <jeroen.leenarts@gmail.com> in commit 815f12c
        defer {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                os_log("Failed to remove item from Inbox: %{public}@", log: OSLog.default, type: .debug, url.absoluteString)
            }
        }
        mainVC?.openForEditing(configFileURL: url)
        return true
    }
}
