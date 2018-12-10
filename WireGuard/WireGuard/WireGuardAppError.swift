// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

protocol WireGuardAppError: Error {
    func alertText() -> (/* title */ String, /* message */ String)?
}
