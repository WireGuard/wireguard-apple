//
//  AppDelegate.swift
//  WireGuard
//
//  Created by Roopesh Chander on 11/08/18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = UIColor.white
        self.window = window

        window.rootViewController = MainViewController()
        window.makeKeyAndVisible()

        return true
    }
}
