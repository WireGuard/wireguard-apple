// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit
import os.log

class ErrorPresenter {
    static func showErrorAlert(error: WireGuardAppError, from sourceVC: UIViewController?,
                               onPresented: (() -> Void)? = nil, onDismissal: (() -> Void)? = nil) {
        guard let sourceVC = sourceVC else { return }
        guard let (title, message) = error.alertText() else { return }
        let okAction = UIAlertAction(title: "OK", style: .default) { (_) in
            onDismissal?()
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)

        sourceVC.present(alert, animated: true, completion: onPresented)
    }

    static func showErrorAlert(title: String, message: String, from sourceVC: UIViewController?,
                               onPresented: (() -> Void)? = nil, onDismissal: (() -> Void)? = nil) {
        guard let sourceVC = sourceVC else { return }
        let okAction = UIAlertAction(title: "OK", style: .default) { (_) in
            onDismissal?()
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)

        sourceVC.present(alert, animated: true, completion: onPresented)
    }
}
