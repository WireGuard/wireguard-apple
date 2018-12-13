// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

protocol WireGuardAppError: Error {
    typealias AlertText = (title: String, message: String)
    func alertText() -> AlertText
}
