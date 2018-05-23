//
//  AppDelegate.swift
//  Wireguard
//
//  Created by Jeroen Leenarts on 23-05-18.
//  Copyright © 2018 Wireguard. All rights reserved.
//

import UIKit

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
}
