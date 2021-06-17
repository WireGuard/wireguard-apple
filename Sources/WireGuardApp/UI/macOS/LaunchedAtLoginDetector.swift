// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Cocoa

class LaunchedAtLoginDetector {
    static let launchCode = "LaunchedByWireGuardLoginItemHelper"

    static func isLaunchedAtLogin(openAppleEvent: NSAppleEventDescriptor) -> Bool {
        guard isOpenEvent(openAppleEvent) else { return false }
        guard let propData = openAppleEvent.paramDescriptor(forKeyword: keyAEPropData) else { return false }
        return propData.stringValue == launchCode
    }

    static func isReopenedByLoginItemHelper(reopenAppleEvent: NSAppleEventDescriptor) -> Bool {
        guard isReopenEvent(reopenAppleEvent) else { return false }
        guard let propData = reopenAppleEvent.paramDescriptor(forKeyword: keyAEPropData) else { return false }
        return propData.stringValue == launchCode
    }
}

private func isOpenEvent(_ event: NSAppleEventDescriptor) -> Bool {
    return event.eventClass == kCoreEventClass && event.eventID == kAEOpenApplication
}

private func isReopenEvent(_ event: NSAppleEventDescriptor) -> Bool {
    return event.eventClass == kCoreEventClass && event.eventID == kAEReopenApplication
}
