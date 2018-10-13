//
//  MainViewController.swift
//  WireGuard
//
//  Created by Roopesh Chander on 11/08/18.
//  Copyright © 2018 Roopesh Chander. All rights reserved.
//

import UIKit

class MainViewController: UISplitViewController {
    override func loadView() {
        let detailVC = UIViewController()
        let detailNC = UINavigationController(rootViewController: detailVC)

        let masterVC = TunnelsListTableViewController()
        let masterNC = UINavigationController(rootViewController: masterVC)

        self.viewControllers = [ masterNC, detailNC ]

        super.loadView()
    }
}
