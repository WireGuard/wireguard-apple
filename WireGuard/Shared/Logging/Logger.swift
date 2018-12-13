// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import os.log

public class Logger {
    static var global: Logger?

    var log: OpaquePointer?
    var tag: String

    init(withFilePath filePath: String, withTag tag: String) {
        self.tag = tag
        self.log = filePath.withCString { fileC -> OpaquePointer? in
            open_log(fileC)
        }
        if self.log == nil {
            os_log("Cannot open log file for writing. Log will not be saved to file.", log: OSLog.default, type: .error)
        }
    }

    func log(message: String) {
        guard let log = log else { return }
        String(format: "[%@] %@", tag, message.trimmingCharacters(in: .newlines)).withCString { messageC in
            write_msg_to_log(log, messageC)
        }
    }

    func writeLog(mergedWith otherLogFile: String, to targetFile: String) -> Bool {
        guard let log = log else { return false }
        guard let other = otherLogFile.withCString({ otherC -> OpaquePointer? in
            return open_log(otherC)
        }) else { return false }
        defer { close_log(other) }
        return targetFile.withCString { fileC -> Bool in
            return write_logs_to_file(fileC, log, other) == 0
        }
    }

    static func configureGlobal(withFilePath filePath: String?, withTag tag: String) {
        if Logger.global != nil {
            return
        }
        guard let filePath = filePath else {
            os_log("Unable to determine log destination path. Log will not be saved to file.", log: OSLog.default, type: .error)
            return
        }
        Logger.global = Logger(withFilePath: filePath, withTag: tag)
        var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
        if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion += " (\(appBuild))"
        }
        let goBackendVersion = WIREGUARD_GO_VERSION
        Logger.global?.log(message: "App version: \(appVersion); Go backend version: \(goBackendVersion)")

    }
}

func wg_log(_ type: OSLogType, staticMessage msg: StaticString) {
    os_log(msg, log: OSLog.default, type: type)
    Logger.global?.log(message: "\(msg)")
}

func wg_log(_ type: OSLogType, message msg: String) {
    os_log("%{public}s", log: OSLog.default, type: type, msg)
    Logger.global?.log(message: msg)
}
