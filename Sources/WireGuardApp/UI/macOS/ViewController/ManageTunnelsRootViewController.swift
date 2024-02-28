// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class ManageTunnelsRootViewController: NSViewController {

    let tunnelsManager: TunnelsManager
    var tunnelsListVC: TunnelsListTableViewController?
    var tunnelDetailVC: TunnelDetailTableViewController?
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

        let horizontalSpacing: CGFloat = 20
        let verticalSpacing: CGFloat = 20
        let centralSpacing: CGFloat = 10

        let container = NSLayoutGuide()
        view.addLayoutGuide(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: verticalSpacing),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: verticalSpacing),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalSpacing),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: horizontalSpacing)
        ])

        tunnelsListVC = TunnelsListTableViewController(tunnelsManager: tunnelsManager)
        tunnelsListVC!.delegate = self
        let tunnelsListView = tunnelsListVC!.view

        addChild(tunnelsListVC!)
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
            tunnelDetailContainerView.leadingAnchor.constraint(equalTo: tunnelsListView.trailingAnchor, constant: centralSpacing),
            tunnelDetailContainerView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
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
    func tunnelsSelected(tunnelIndices: [Int]) {
        assert(!tunnelIndices.isEmpty)
        if tunnelIndices.count == 1 {
            let tunnel = tunnelsManager.tunnel(at: tunnelIndices.first!)
            if tunnel.isTunnelAvailableToUser {
                let tunnelDetailVC = TunnelDetailTableViewController(tunnelsManager: tunnelsManager, tunnel: tunnel)
                setTunnelDetailContentVC(tunnelDetailVC)
                self.tunnelDetailVC = tunnelDetailVC
            } else {
                let unusableTunnelDetailVC = tunnelDetailContentVC as? UnusableTunnelDetailViewController ?? UnusableTunnelDetailViewController()
                unusableTunnelDetailVC.onButtonClicked = { [weak tunnelsListVC] in
                    tunnelsListVC?.handleRemoveTunnelAction()
                }
                setTunnelDetailContentVC(unusableTunnelDetailVC)
                self.tunnelDetailVC = nil
            }
        } else if tunnelIndices.count > 1 {
            let multiSelectionVC = tunnelDetailContentVC as? ButtonedDetailViewController ?? ButtonedDetailViewController()
            multiSelectionVC.setButtonTitle(tr(format: "macButtonDeleteTunnels (%d)", tunnelIndices.count))
            multiSelectionVC.onButtonClicked = { [weak tunnelsListVC] in
                tunnelsListVC?.handleRemoveTunnelAction()
            }
            setTunnelDetailContentVC(multiSelectionVC)
            self.tunnelDetailVC = nil
        }
    }

    func tunnelsListEmpty() {
        let noTunnelsVC = ButtonedDetailViewController()
        noTunnelsVC.setButtonTitle(tr("macButtonImportTunnels"))
        noTunnelsVC.onButtonClicked = { [weak self] in
            guard let self = self else { return }
            ImportPanelPresenter.presentImportPanel(tunnelsManager: self.tunnelsManager, sourceVC: self)
        }
        setTunnelDetailContentVC(noTunnelsVC)
        self.tunnelDetailVC = nil
    }
}

extension ManageTunnelsRootViewController {
    override func supplementalTarget(forAction action: Selector, sender: Any?) -> Any? {
        switch action {
        case #selector(TunnelsListTableViewController.handleViewLogAction),
             #selector(TunnelsListTableViewController.handleAddEmptyTunnelAction),
             #selector(TunnelsListTableViewController.handleImportTunnelAction),
             #selector(TunnelsListTableViewController.handleExportTunnelsAction),
             #selector(TunnelsListTableViewController.handleRemoveTunnelAction):
            return tunnelsListVC
        case #selector(TunnelDetailTableViewController.handleToggleActiveStatusAction),
             #selector(TunnelDetailTableViewController.handleEditTunnelAction):
            return tunnelDetailVC
        default:
            return super.supplementalTarget(forAction: action, sender: sender)
        }
    }
}
