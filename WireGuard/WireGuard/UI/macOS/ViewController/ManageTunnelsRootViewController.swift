// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

class ManageTunnelsRootViewController: NSViewController {

    let tunnelsManager: TunnelsManager
    let tunnelDetailContainerView = NSView()
    var tunnelDetailContentVC: NSViewController?

    init(tunnelsManager: TunnelsManager) {
        self.tunnelsManager = tunnelsManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()

        let horizontalSpacing: CGFloat = 30
        let verticalSpacing: CGFloat = 20

        let container = NSLayoutGuide()
        view.addLayoutGuide(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: verticalSpacing),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: verticalSpacing),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalSpacing),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: horizontalSpacing)
        ])

        let tunnelsListVC = TunnelsListTableViewController(tunnelsManager: tunnelsManager)
        tunnelsListVC.delegate = self
        let tunnelsListView = tunnelsListVC.view

        addChild(tunnelsListVC)
        view.addSubview(tunnelsListView)
        view.addSubview(tunnelDetailContainerView)

        tunnelsListView.translatesAutoresizingMaskIntoConstraints = false
        tunnelDetailContainerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            tunnelsListView.topAnchor.constraint(equalTo: container.topAnchor),
            tunnelsListView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            tunnelsListView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tunnelDetailContainerView.topAnchor.constraint(equalTo: container.topAnchor),
            tunnelDetailContainerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            tunnelDetailContainerView.leadingAnchor.constraint(equalTo: tunnelsListView.trailingAnchor, constant: horizontalSpacing),
            tunnelDetailContainerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tunnelsListView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.3)
        ])
    }

    private func setTunnelDetailContentVC(_ contentVC: NSViewController) {
        if let currentContentVC = tunnelDetailContentVC {
            currentContentVC.view.removeFromSuperview()
            currentContentVC.removeFromParent()
        }
        addChild(contentVC)
        tunnelDetailContainerView.addSubview(contentVC.view)
        contentVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tunnelDetailContainerView.topAnchor.constraint(equalTo: contentVC.view.topAnchor),
            tunnelDetailContainerView.bottomAnchor.constraint(equalTo: contentVC.view.bottomAnchor),
            tunnelDetailContainerView.leadingAnchor.constraint(equalTo: contentVC.view.leadingAnchor),
            tunnelDetailContainerView.trailingAnchor.constraint(equalTo: contentVC.view.trailingAnchor)
        ])
        tunnelDetailContentVC = contentVC
    }
}

extension ManageTunnelsRootViewController: TunnelsListTableViewControllerDelegate {
    func tunnelSelected(tunnel: TunnelContainer) {
        let tunnelDetailVC = TunnelDetailTableViewController(tunnelsManager: tunnelsManager, tunnel: tunnel)
        setTunnelDetailContentVC(tunnelDetailVC)
    }

    func tunnelListEmpty() {
        // TODO
    }
}
