// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import os.log

class Logger {
    static var logPtr: UnsafeMutablePointer<log>?

    static func configure(withFilePath filePath: String) -> Bool {
        let logPtr = filePath.withCString { filePathCStr -> UnsafeMutablePointer<log>? in
            return open_log(filePathCStr)
        }
        Logger.logPtr = logPtr
        return (logPtr != nil)
    }

    static func writeLog(mergedWith otherLogFile: String, tag: String, otherTag: String, to targetFile: String) -> Bool {
        let otherlogPtr = otherLogFile.withCString { otherLogFileCStr -> UnsafeMutablePointer<log>? in
            return open_log(otherLogFileCStr)
        }
        if let thisLogPtr = Logger.logPtr, let otherlogPtr = otherlogPtr {
            return targetFile.withCString { targetFileCStr -> Bool in
                return tag.withCString { tagCStr -> Bool in
                    return otherTag.withCString { otherTagCStr -> Bool in
                        let returnValue = write_logs_to_file(targetFileCStr, tagCStr, thisLogPtr, otherTagCStr, otherlogPtr)
                        return (returnValue == 0)
                    }
                }
            }
        }
        return false
    }
}

func wg_log(_ type: OSLogType, staticMessage msg: StaticString) {
    // Write to os log
    os_log(msg, log: OSLog.default, type: type)
    // Write to file log
    let msgString: String = msg.withUTF8Buffer { (ptr: UnsafeBufferPointer<UInt8>) -> String in
        return String(decoding: ptr, as: UTF8.self)
    }
    file_log(type: type, message: msgString)
}

func wg_log(_ type: OSLogType, message msg: String) {
    // Write to os log
    os_log("%{public}s", log: OSLog.default, type: type, msg)
    // Write to file log
    file_log(type: type, message: msg)
}

private func file_log(type: OSLogType, message: String) {
    message.withCString { messageCStr in
        if let logPtr = Logger.logPtr {
            write_msg_to_log(logPtr, messageCStr)
        }
    }
}
