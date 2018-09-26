//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation

extension AppCoordinator: QRScanViewControllerDelegate {
    func didSave(tunnel: Tunnel, qrScanViewController: QRScanViewController) {
        qrScanViewController.navigationController?.popViewController(animated: true)
        showTunnelInfoViewController(tunnel: tunnel, context: tunnel.managedObjectContext!)
    }

    func didCancel(qrScanViewController: QRScanViewController) {
        qrScanViewController.navigationController?.popViewController(animated: true)
    }
}
