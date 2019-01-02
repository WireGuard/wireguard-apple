// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

protocol WireGuardAppError: Error {
    typealias AlertText = (title: String, message: String)

    var alertText: AlertText { get }
}
