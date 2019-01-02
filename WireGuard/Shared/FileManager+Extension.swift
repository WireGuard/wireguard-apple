// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation
import os.log

extension FileManager {
    private static var sharedFolderURL: URL? {
        guard let appGroupId = Bundle.main.object(forInfoDictionaryKey: "com.wireguard.ios.app_group_id") as? String else {
            os_log("Cannot obtain app group ID from bundle", log: OSLog.default, type: .error)
            return nil
        }
        guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            wg_log(.error, message: "Cannot obtain shared folder URL")
            return nil
        }
        return sharedFolderURL
    }

    static var networkExtensionLogFileURL: URL? {
        return sharedFolderURL?.appendingPathComponent("tunnel-log.bin")
    }

    static var networkExtensionLastErrorFileURL: URL? {
        return sharedFolderURL?.appendingPathComponent("last-error.txt")
    }

    static var appLogFileURL: URL? {
        guard let documentDirURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            wg_log(.error, message: "Cannot obtain app documents folder URL")
            return nil
        }
        return documentDirURL.appendingPathComponent("app-log.bin")
    }

    static func deleteFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            return false
        }
        return true
    }
}
