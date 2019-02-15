// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Cocoa

class ImportPanelPresenter {
    static func presentImportPanel(tunnelsManager: TunnelsManager, sourceVC: NSViewController?) {
        guard let window = sourceVC?.view.window else { return }
        let openPanel = NSOpenPanel()
        openPanel.prompt = tr("macSheetButtonImport")
        openPanel.allowedFileTypes = ["conf", "zip"]
        openPanel.beginSheetModal(for: window) { [weak tunnelsManager] response in
            guard let tunnelsManager = tunnelsManager else { return }
            guard response == .OK else { return }
            guard let url = openPanel.url else { return }
            AppStorePrivacyNotice.show(from: sourceVC, into: tunnelsManager) {
                TunnelImporter.importFromFile(url: url, into: tunnelsManager, sourceVC: sourceVC, errorPresenterType: ErrorPresenter.self)
            }
        }
    }
}
