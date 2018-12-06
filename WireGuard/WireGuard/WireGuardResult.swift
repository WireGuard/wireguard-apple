// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

enum WireGuardResult<T> {
    case success(T)
    case failure(WireGuardAppError)

    var value: T? {
        switch (self) {
        case .success(let v): return v
        case .failure(_): return nil
        }
    }

    var error: WireGuardAppError? {
        switch (self) {
        case .success(_): return nil
        case .failure(let e): return e
        }
    }

    var isSuccess: Bool {
        switch (self) {
        case .success(_): return true
        case .failure(_): return false
        }
    }
}
