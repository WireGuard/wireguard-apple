// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import os.log

extension FileManager {
    static var networkExtensionLogFileURL: URL? {
        guard let appGroupId = Bundle.main.object(forInfoDictionaryKey: "com.wireguard.ios.app_group_id") as? String else {
            os_log("Cannot obtain app group id from bundle", log: OSLog.default, type: .error)
            return nil
        }
        guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            os_log("Cannot obtain shared folder URL", log: OSLog.default, type: .error)
            return nil
        }
        return sharedFolderURL.appendingPathComponent("tunnel-log.txt")
    }

    static var networkExtensionLastErrorFileURL: URL? {
        guard let appGroupId = Bundle.main.object(forInfoDictionaryKey: "com.wireguard.ios.app_group_id") as? String else {
            os_log("Cannot obtain app group id from bundle", log: OSLog.default, type: .error)
            return nil
        }
        guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            os_log("Cannot obtain shared folder URL", log: OSLog.default, type: .error)
            return nil
        }
        return sharedFolderURL.appendingPathComponent("last-error.txt")
    }

    static var appLogFileURL: URL? {
        guard let documentDirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            os_log("Cannot obtain app documents folder URL", log: OSLog.default, type: .error)
            return nil
        }
        return documentDirURL.appendingPathComponent("app-log.txt")
    }

    static func deleteFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error {
            wg_log(.info, message: "Failed to delete file '\(url.path)': \(error)")
            return false
        }
        return true
    }
}
