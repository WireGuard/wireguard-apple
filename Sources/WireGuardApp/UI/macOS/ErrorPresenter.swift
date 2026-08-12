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
            // WireGuard runs as a menu bar (accessory) app, which is usually
            // not the active app. A modal alert shown while inactive comes up
            // behind other windows with no way to reach it, freezing the app
            // until it is dismissed. Activate first so the alert is visible.
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            onDismissal?()
        }
    }
}
