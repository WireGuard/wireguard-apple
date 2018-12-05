// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import os.log

extension FileManager {
    static var networkExtensionLogFileURL: URL? {
        guard let appGroupId = Bundle.main.object(forInfoDictionaryKey: "com.wireguard.ios.app_group_id") as? String else {
            os_log("Can't obtain app group id from bundle", log: OSLog.default, type: .error)
            return nil
        }
        guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            os_log("Can't obtain shared folder URL", log: OSLog.default, type: .error)
            return nil
        }
        return sharedFolderURL.appendingPathComponent("lastActivatedTunnelLog.txt")
    }

    static func deleteFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
        } catch(let e) {
            os_log("Failed to delete file '%{public}@': %{public}@", log: OSLog.default, type: .debug, url.absoluteString, e.localizedDescription)
            return false
        }
        return true
    }
}
