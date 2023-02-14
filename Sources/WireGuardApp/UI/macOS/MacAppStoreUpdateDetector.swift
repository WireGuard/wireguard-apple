// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class MacAppStoreUpdateDetector {
    static func isUpdatingFromMacAppStore(quitAppleEvent: NSAppleEventDescriptor) -> Bool {
        guard isQuitEvent(quitAppleEvent) else { return false }
        guard let senderPIDDescriptor = quitAppleEvent.attributeDescriptor(forKeyword: keySenderPIDAttr) else { return false }
        let pid = senderPIDDescriptor.int32Value
        wg_log(.debug, message: "aevt/quit Apple event received from pid: \(pid)")
        guard let executablePath = getExecutablePath(from: pid) else { return false }
        wg_log(.debug, message: "aevt/quit Apple event received from executable: \(executablePath)")
        if executablePath.hasPrefix("/System/Library/") {
            let executableName = URL(fileURLWithPath: executablePath, isDirectory: false).lastPathComponent
            return executableName.hasPrefix("com.apple.") && executableName.hasSuffix(".StoreAEService")
        }
        return false
    }
}

private func isQuitEvent(_ event: NSAppleEventDescriptor) -> Bool {
    return event.eventClass == kCoreEventClass && event.eventID == kAEQuitApplication
}

private func getExecutablePath(from pid: pid_t) -> String? {
    let bufferSize = Int(PATH_MAX)
    var buffer = Data(capacity: bufferSize)
    return buffer.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) -> String? in
        if let basePtr = ptr.baseAddress {
            let byteCount = proc_pidpath(pid, basePtr, UInt32(bufferSize))
            return byteCount > 0 ? String(cString: basePtr.bindMemory(to: CChar.self, capacity: bufferSize)) : nil
        }
        return nil
    }
}
