// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

class ManageTunnelsRootViewController: NSViewController {

    let tunnelsManager: TunnelsManager

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
        let tunnelsListView = tunnelsListVC.view
        let tunnelDetailView = NSView()
        tunnelDetailView.wantsLayer = true
        tunnelDetailView.layer?.backgroundColor = NSColor.gray.cgColor

        addChild(tunnelsListVC)
        view.addSubview(tunnelsListView)
        view.addSubview(tunnelDetailView)

        tunnelsListView.translatesAutoresizingMaskIntoConstraints = false
        tunnelDetailView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            tunnelsListView.topAnchor.constraint(equalTo: container.topAnchor),
            tunnelsListView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            tunnelsListView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tunnelDetailView.leadingAnchor.constraint(equalTo: tunnelsListView.trailingAnchor, constant: horizontalSpacing),
            tunnelDetailView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tunnelsListView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.3)
        ])
    }
}
