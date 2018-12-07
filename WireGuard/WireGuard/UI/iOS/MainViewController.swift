// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

class MainViewController: UISplitViewController {

    var tunnelsManager: TunnelsManager?
    var onTunnelsManagerReady: ((TunnelsManager) -> Void)?

    var tunnelsListVC: TunnelsListTableViewController?

    init() {
        let detailVC = UIViewController()
        detailVC.view.backgroundColor = UIColor.white
        let detailNC = UINavigationController(rootViewController: detailVC)

        let masterVC = TunnelsListTableViewController()
        let masterNC = UINavigationController(rootViewController: masterVC)

        self.tunnelsListVC = masterVC

        super.init(nibName: nil, bundle: nil)

        self.viewControllers = [ masterNC, detailNC ]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        self.delegate = self

        // On iPad, always show both masterVC and detailVC, even in portrait mode, like the Settings app
        self.preferredDisplayMode = .allVisible

        // Create the tunnels manager, and when it's ready, inform tunnelsListVC
        TunnelsManager.create { [weak self] result in
            if let error = result.error {
                ErrorPresenter.showErrorAlert(error: error, from: self)
                return
            }
            let tunnelsManager: TunnelsManager = result.value!
            guard let s = self else { return }

            s.tunnelsManager = tunnelsManager
            s.tunnelsListVC?.setTunnelsManager(tunnelsManager: tunnelsManager)

            tunnelsManager.activationDelegate = s

            s.onTunnelsManagerReady?(tunnelsManager)
            s.onTunnelsManagerReady = nil
        }
    }
}

extension MainViewController: TunnelsManagerActivationDelegate {
    func tunnelActivationFailed(tunnel: TunnelContainer, error: TunnelsManagerError) {
        ErrorPresenter.showErrorAlert(error: error, from: self)
    }
}

extension MainViewController {
    func refreshTunnelConnectionStatuses() {
        if let tunnelsManager = tunnelsManager {
            tunnelsManager.refreshStatuses()
        }
    }
}

extension MainViewController: UISplitViewControllerDelegate {
    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController: UIViewController,
                             onto primaryViewController: UIViewController) -> Bool {
        // On iPhone, if the secondaryVC (detailVC) is just a UIViewController, it indicates that it's empty,
        // so just show the primaryVC (masterVC).
        let detailVC = (secondaryViewController as? UINavigationController)?.viewControllers.first
        let isDetailVCEmpty: Bool
        if let detailVC = detailVC {
            isDetailVCEmpty = (type(of: detailVC) == UIViewController.self)
        } else {
            isDetailVCEmpty = true
        }
        return isDetailVCEmpty
    }
}
