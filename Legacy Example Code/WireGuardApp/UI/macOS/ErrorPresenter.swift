// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class ErrorPresenter: ErrorPresenterProtocol {
    static func showErrorAlert(title: String, message: String, from sourceVC: AnyObject?, onPresented: (() -> Void)?, onDismissal: (() -> Void)?) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        onPresented?()
        if let sourceVC = sourceVC as? NSViewController {
            NSApp.activate(ignoringOtherApps: true)
            sourceVC.view.window!.makeKeyAndOrderFront(nil)
            alert.beginSheetModal(for: sourceVC.view.window!) { _ in
                onDismissal?()
            }
        } else {
            alert.runModal()
            onDismissal?()
        }
    }
}
