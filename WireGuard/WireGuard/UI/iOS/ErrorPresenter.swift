// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit
import os.log

class ErrorPresenter {
    static func errorMessage(for error: Error) -> (String, String)? {
        switch (error) {
        case TunnelManagementError.tunnelAlreadyExistsWithThatName:
            return ("Name already in use", "A tunnel with that name already exists. Please pick a different name.")
        case TunnelManagementError.vpnSystemErrorOnAddTunnel:
            return ("Could not create tunnel", "Internal error")
        case TunnelManagementError.vpnSystemErrorOnModifyTunnel:
            return ("Could not modify tunnel", "Internal error")
        case TunnelManagementError.vpnSystemErrorOnRemoveTunnel:
            return ("Could not remove tunnel", "Internal error")
        default:
            os_log("ErrorPresenter: Error not presented: %{public}@", log: OSLog.default, type: .error, "\(error)")
            return nil
        }
    }

    static func showErrorAlert(error: Error, from sourceVC: UIViewController?, onDismissal: (() -> Void)? = nil) {
        guard let sourceVC = sourceVC else { return }
        guard let (title, message) = ErrorPresenter.errorMessage(for: error) else { return }
        let okAction = UIAlertAction(title: "Ok", style: .default) { (_) in
            onDismissal?()
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)

        sourceVC.present(alert, animated: true)
    }

    static func showErrorAlert(title: String, message: String, from sourceVC: UIViewController?, onDismissal: (() -> Void)? = nil) {
        guard let sourceVC = sourceVC else { return }
        let okAction = UIAlertAction(title: "Ok", style: .default) { (_) in
            onDismissal?()
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)

        sourceVC.present(alert, animated: true)
    }
}
