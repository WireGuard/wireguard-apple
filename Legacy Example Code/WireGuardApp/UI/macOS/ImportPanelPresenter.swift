// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class ImportPanelPresenter {
    static func presentImportPanel(tunnelsManager: TunnelsManager, sourceVC: NSViewController?) {
        guard let window = sourceVC?.view.window else { return }
        let openPanel = NSOpenPanel()
        openPanel.prompt = tr("macSheetButtonImport")
        openPanel.allowedFileTypes = ["conf", "zip"]
        openPanel.allowsMultipleSelection = true
        openPanel.beginSheetModal(for: window) { [weak tunnelsManager] response in
            guard let tunnelsManager = tunnelsManager else { return }
            guard response == .OK else { return }
            TunnelImporter.importFromFile(urls: openPanel.urls, into: tunnelsManager, sourceVC: sourceVC, errorPresenterType: ErrorPresenter.self)
        }
    }
}
