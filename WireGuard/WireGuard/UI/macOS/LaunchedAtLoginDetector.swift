// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Cocoa

class LaunchedAtLoginDetector {
    static func isLaunchedAtLogin(openAppleEvent: NSAppleEventDescriptor) -> Bool {
        let launchCode = "LaunchedByWireGuardLoginItemHelper"
        guard isOpenEvent(openAppleEvent) else { return false }
        guard let propData = openAppleEvent.paramDescriptor(forKeyword: keyAEPropData) else { return false }
        return propData.stringValue == launchCode
    }
}

private func isOpenEvent(_ event: NSAppleEventDescriptor) -> Bool {
    return event.eventClass == kCoreEventClass && event.eventID == kAEOpenApplication
}
