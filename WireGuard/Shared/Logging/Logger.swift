// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation
import os.log

public class Logger {
    enum LoggerError: Error {
        case openFailure
    }

    static var global: Logger?

    var log: OpaquePointer

    init(withFilePath filePath: String) throws {
        guard let log = open_log(filePath) else { throw LoggerError.openFailure }
        self.log = log
    }

    deinit {
        close_log(self.log)
    }

    func log(message: String) {
        write_msg_to_log(log, message.trimmingCharacters(in: .newlines))
    }

    func writeLog(called ourTag: String, mergedWith otherLogFile: String, called otherTag: String, to targetFile: String) -> Bool {
        guard let other = open_log(otherLogFile) else { return false }
        let ret = write_logs_to_file(targetFile, log, ourTag, other, otherTag)
        close_log(other)
        return ret == 0
    }

    static func configureGlobal(withFilePath filePath: String?) {
        if Logger.global != nil {
            return
        }
        guard let filePath = filePath else {
            os_log("Unable to determine log destination path. Log will not be saved to file.", log: OSLog.default, type: .error)
            return
        }
        guard let logger = try? Logger(withFilePath: filePath) else {
            os_log("Unable to open log file for writing. Log will not be saved to file.", log: OSLog.default, type: .error)
            return
        }
        Logger.global = logger
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
