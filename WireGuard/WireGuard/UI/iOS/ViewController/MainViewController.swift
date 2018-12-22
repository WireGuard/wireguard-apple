// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

class MainViewController: UISplitViewController {

    var tunnelsManager: TunnelsManager?
    var onTunnelsManagerReady: ((TunnelsManager) -> Void)?
    var tunnelsListVC: TunnelsListTableViewController?
    private var foregroundObservationToken: AnyObject?

    init() {
        let detailVC = UIViewController()
        detailVC.view.backgroundColor = .white
        let detailNC = UINavigationController(rootViewController: detailVC)

        let masterVC = TunnelsListTableViewController()
        let masterNC = UINavigationController(rootViewController: masterVC)

        tunnelsListVC = masterVC

        super.init(nibName: nil, bundle: nil)

        viewControllers = [ masterNC, detailNC ]

        restorationIdentifier = "MainVC"
        masterNC.restorationIdentifier = "MasterNC"
        detailNC.restorationIdentifier = "DetailNC"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        delegate = self

        // On iPad, always show both masterVC and detailVC, even in portrait mode, like the Settings app
        preferredDisplayMode = .allVisible

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

        foregroundObservationToken = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            guard let self = self else { return }
            self.tunnelsManager?.reload { [weak self] hasChanges in
                guard let self = self, let tunnelsManager = self.tunnelsManager, hasChanges else { return }

                self.tunnelsListVC?.setTunnelsManager(tunnelsManager: tunnelsManager)

                if self.isCollapsed {
                    (self.viewControllers[0] as? UINavigationController)?.popViewController(animated: false)
                } else {
                    let detailVC = UIViewController()
                    detailVC.view.backgroundColor = .white
                    let detailNC = UINavigationController(rootViewController: detailVC)
                    self.showDetailViewController(detailNC, sender: self)
                }

                if let presentedNavController = self.presentedViewController as? UINavigationController, presentedNavController.viewControllers.first is TunnelEditTableViewController {
                    self.presentedViewController?.dismiss(animated: false, completion: nil)
                }
            }

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
