// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import UIKit

class FileImportViewController: UIDocumentPickerViewController {
    enum DocumentType: String {
        case wgQuickConfigFile = "com.wireguard.config.quick"
    }

    init(documentTypes: [DocumentType]) {
        super.init(documentTypes: documentTypes.map { $0.rawValue }, in: .import)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
