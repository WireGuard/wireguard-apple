// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Cocoa

class AppStorePrivacyNotice {
    // The App Store Review Board does not comprehend the fact that this application
    // is not a service and does not have any servers of its own. They therefore require
    // us to give a notice regarding collection of user data using our non-existent
    // servers. This demand is obviously impossible to fulfill, since it doesn't make sense,
    // but we do our best here to show something in that category.
    static func show(from sourceVC: NSViewController?, into tunnelsManager: TunnelsManager, _ callback: @escaping () -> Void) {
        if tunnelsManager.numberOfTunnels() > 0 {
            callback()
            return
        }
        let alert = NSAlert()

        alert.messageText = tr("macPrivacyNoticeMessage")
        alert.informativeText = tr("macPrivacyNoticeInfo")
        alert.alertStyle = NSAlert.Style.warning
        if let window = sourceVC?.view.window {
            alert.beginSheetModal(for: window) { _ in callback() }
        } else {
            alert.runModal()
            callback()
        }
    }
}
