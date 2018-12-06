// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit
import os.log

class ErrorPresenter {
    static func errorMessage(for error: Error) -> (String, String) {

        if let error = error as? WireGuardAppError {
            return error.alertText()
        }

        switch (error) {

        // Importing a zip file
        case ZipArchiveError.cantOpenInputZipFile:
            return ("Unable to read zip archive", "The zip archive could not be read.")
        case ZipArchiveError.badArchive:
            return ("Unable to read zip archive", "Bad or corrupt zip archive.")
        case ZipImporterError.noTunnelsInZipArchive:
            return ("No tunnels in zip archive", "No .conf tunnel files were found inside the zip archive.")

        // Exporting a zip file
        case ZipArchiveError.cantOpenOutputZipFileForWriting:
            return ("Unable to create zip archive", "Could not create a zip file in the app's document directory.")
        case ZipExporterError.noTunnelsToExport:
            return ("Nothing to export", "There are no tunnels to export")

        default:
            return ("Error", error.localizedDescription)
        }
    }

    static func showErrorAlert(error: Error, from sourceVC: UIViewController?,
                               onDismissal: (() -> Void)? = nil, onPresented: (() -> Void)? = nil) {
        guard let sourceVC = sourceVC else { return }
        let (title, message) = ErrorPresenter.errorMessage(for: error)
        let okAction = UIAlertAction(title: "OK", style: .default) { (_) in
            onDismissal?()
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)

        sourceVC.present(alert, animated: true, completion: onPresented)
    }

    static func showErrorAlert(title: String, message: String, from sourceVC: UIViewController?, onDismissal: (() -> Void)? = nil) {
        guard let sourceVC = sourceVC else { return }
        let okAction = UIAlertAction(title: "OK", style: .default) { (_) in
            onDismissal?()
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(okAction)

        sourceVC.present(alert, animated: true)
    }
}
