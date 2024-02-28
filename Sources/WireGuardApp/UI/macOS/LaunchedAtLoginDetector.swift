// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class LaunchedAtLoginDetector {
    static func isLaunchedAtLogin(openAppleEvent: NSAppleEventDescriptor) -> Bool {
        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        guard openAppleEvent.eventClass == kCoreEventClass && openAppleEvent.eventID == kAEOpenApplication else { return false }
        guard let url = FileManager.loginHelperTimestampURL else { return false }
        guard let data = try? Data(contentsOf: url) else { return false }
        _ = FileManager.deleteFile(at: url)
        guard data.count == 8 else { return false }
        let then = data.withUnsafeBytes { ptr in
            ptr.load(as: UInt64.self)
        }
        return now - then <= 20000000000
    }
}
