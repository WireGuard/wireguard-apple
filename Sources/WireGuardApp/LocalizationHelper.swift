// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation

func tr(_ key: String) -> String {
    return NSLocalizedString(key, comment: "")
}

func tr(format: String, _ arguments: CVarArg...) -> String {
    return String(format: NSLocalizedString(format, comment: ""), arguments: arguments)
}
