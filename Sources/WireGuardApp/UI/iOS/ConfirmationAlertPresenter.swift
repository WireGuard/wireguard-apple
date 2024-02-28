// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class ConfirmationAlertPresenter {
    static func showConfirmationAlert(message: String, buttonTitle: String, from sourceObject: AnyObject, presentingVC: UIViewController, onConfirmed: @escaping (() -> Void)) {
        let destroyAction = UIAlertAction(title: buttonTitle, style: .destructive) { _ in
            onConfirmed()
        }
        let cancelAction = UIAlertAction(title: tr("actionCancel"), style: .cancel)
        let alert = UIAlertController(title: "", message: message, preferredStyle: .actionSheet)
        alert.addAction(destroyAction)
        alert.addAction(cancelAction)

        if let sourceView = sourceObject as? UIView {
            alert.popoverPresentationController?.sourceView = sourceView
            alert.popoverPresentationController?.sourceRect = sourceView.bounds
        } else if let sourceBarButtonItem = sourceObject as? UIBarButtonItem {
            alert.popoverPresentationController?.barButtonItem = sourceBarButtonItem
        }

        presentingVC.present(alert, animated: true, completion: nil)
    }
}
