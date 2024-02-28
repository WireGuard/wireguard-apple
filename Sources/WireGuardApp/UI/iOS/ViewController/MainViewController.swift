// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class MainViewController: UISplitViewController {

    var tunnelsManager: TunnelsManager? {
        return (UIApplication.shared.delegate as? AppDelegate)?.tunnelsManager
    }
    var onTunnelsManagerReady: ((TunnelsManager) -> Void)?
    var tunnelsListVC: TunnelsListTableViewController?

    init() {
        let detailVC = UIViewController()
        detailVC.view.backgroundColor = .systemBackground
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

        NotificationCenter.default.addObserver(self, selector: #selector(handleTunnelsManagerReady(_:)),
                                               name: AppDelegate.tunnelsManagerReadyNotificationName, object: nil)
    }

    func allTunnelNames() -> [String]? {
        guard let tunnelsManager = self.tunnelsManager else { return nil }
        return tunnelsManager.mapTunnels { $0.name }
    }

    @objc
    func handleTunnelsManagerReady(_ notification: Notification) {
        guard let tunnelsManager = self.tunnelsManager else { return }

        self.onTunnelsManagerReady?(tunnelsManager)
        self.onTunnelsManagerReady = nil

        NotificationCenter.default.removeObserver(self, name: AppDelegate.tunnelsManagerReadyNotificationName, object: nil)
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

    func showTunnelDetailForTunnel(named tunnelName: String, animated: Bool, shouldToggleStatus: Bool) {
        let showTunnelDetailBlock: (TunnelsManager) -> Void = { [weak self] tunnelsManager in
            guard let self = self else { return }
            guard let tunnelsListVC = self.tunnelsListVC else { return }
            if let tunnel = tunnelsManager.tunnel(named: tunnelName) {
                tunnelsListVC.showTunnelDetail(for: tunnel, animated: false)
                if shouldToggleStatus {
                    if tunnel.status == .inactive {
                        tunnelsManager.startActivation(of: tunnel)
                    } else if tunnel.status == .active {
                        tunnelsManager.startDeactivation(of: tunnel)
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

    func importFromDisposableFile(url: URL) {
        let importFromFileBlock: (TunnelsManager) -> Void = { [weak self] tunnelsManager in
            TunnelImporter.importFromFile(urls: [url], into: tunnelsManager, sourceVC: self, errorPresenterType: ErrorPresenter.self) {
                _ = FileManager.deleteFile(at: url)
            }
        }
        if let tunnelsManager = tunnelsManager {
            importFromFileBlock(tunnelsManager)
        } else {
            onTunnelsManagerReady = importFromFileBlock
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
