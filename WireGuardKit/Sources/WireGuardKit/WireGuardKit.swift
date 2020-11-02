// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation
import libwg_go

public func getWireGuardVersion() -> String {
    return String(cString: wgVersion()!)
}
