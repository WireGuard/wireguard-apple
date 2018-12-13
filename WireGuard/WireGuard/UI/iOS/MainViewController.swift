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

        // State restoration
        self.restorationIdentifier = "MainVC"
        masterNC.restorationIdentifier = "MasterNC"
        detailNC.restorationIdentifier = "DetailNC"
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
            guard let self = self else { return }

            if let error = result.error {
                ErrorPresenter.showErrorAlert(error: error, from: self)
                return
            }
            let tunnelsManager: TunnelsManager = result.value!

            self.tunnelsManager = tunnelsManager
            self.tunnelsListVC?.setTunnelsManager(tunnelsManager: tunnelsManager)

            tunnelsManager.activationDelegate = self

            self.onTunnelsManagerReady?(tunnelsManager)
        self.onTunnelsManagerReady = nil
        }
    }
}

extension MainViewController: TunnelsManagerActivationDelegate {
    func tunnelActivationAttemptFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationAttemptError) {
        ErrorPresenter.showErrorAlert(error: error, from: self)
    }

    func tunnelActivationAttemptSucceeded(tunnel: TunnelContainer) {
        // Nothing to do
    }

    func tunnelActivationFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationError) {
        ErrorPresenter.showErrorAlert(error: error, from: self)
    }

    func tunnelActivationSucceeded(tunnel: TunnelContainer) {
        // Nothing to do
    }
}

extension MainViewController {
    func refreshTunnelConnectionStatuses() {
        if let tunnelsManager = tunnelsManager {
            tunnelsManager.refreshStatuses()
        }
    }

    func showTunnelDetailForTunnel(named tunnelName: String, animated: Bool) {
        let showTunnelDetailBlock: (TunnelsManager) -> Void = { [weak self] tunnelsManager in
            if let tunnel = tunnelsManager.tunnel(named: tunnelName) {
                let tunnelDetailVC = TunnelDetailTableViewController(tunnelsManager: tunnelsManager, tunnel: tunnel)
                let tunnelDetailNC = UINavigationController(rootViewController: tunnelDetailVC)
                tunnelDetailNC.restorationIdentifier = "DetailNC"
                if let self = self {
                    if animated {
                        self.showDetailViewController(tunnelDetailNC, sender: self)
                    } else {
                        UIView.performWithoutAnimation {
                            self.showDetailViewController(tunnelDetailNC, sender: self)
                        }
                    }
                }
            }
        }
        if let tunnelsManager = tunnelsManager {
            showTunnelDetailBlock(tunnelsManager)
        } else {
            onTunnelsManagerReady = showTunnelDetailBlock
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
