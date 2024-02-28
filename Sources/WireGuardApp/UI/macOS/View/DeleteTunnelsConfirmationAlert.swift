// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class DeleteTunnelsConfirmationAlert: NSAlert {
    var alertDeleteButton: NSButton?
    var alertCancelButton: NSButton?

    var onDeleteClicked: ((_ completionHandler: @escaping () -> Void) -> Void)?

    override init() {
        super.init()
        let alertDeleteButton = addButton(withTitle: tr("macDeleteTunnelConfirmationAlertButtonTitleDelete"))
        alertDeleteButton.target = self
        alertDeleteButton.action = #selector(removeTunnelAlertDeleteClicked)
        self.alertDeleteButton = alertDeleteButton
        self.alertCancelButton = addButton(withTitle: tr("macDeleteTunnelConfirmationAlertButtonTitleCancel"))
    }

    @objc func removeTunnelAlertDeleteClicked() {
        alertDeleteButton?.title = tr("macDeleteTunnelConfirmationAlertButtonTitleDeleting")
        alertDeleteButton?.isEnabled = false
        alertCancelButton?.isEnabled = false
        if let onDeleteClicked = onDeleteClicked {
            onDeleteClicked { [weak self] in
                guard let self = self else { return }
                self.window.sheetParent?.endSheet(self.window)
            }
        }
    }

    func beginSheetModal(for sheetWindow: NSWindow) {
        beginSheetModal(for: sheetWindow) { _ in }
    }
}
