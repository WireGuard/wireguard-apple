// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation

extension Data {
    func isKey() -> Bool {
        return self.count == WG_KEY_LEN
    }

    func hexKey() -> String? {
        if self.count != WG_KEY_LEN {
            return nil
        }
        var out = Data(repeating: 0, count: Int(WG_KEY_LEN_HEX))
        out.withUnsafeMutableBytes { outBytes in
            self.withUnsafeBytes { inBytes in
                key_to_hex(outBytes, inBytes)
            }
        }
        out.removeLast()
        return String(data: out, encoding: .ascii)
    }

    init?(hexKey hexString: String) {
        self.init(repeating: 0, count: Int(WG_KEY_LEN))

        if !self.withUnsafeMutableBytes { key_from_hex($0, hexString) } {
            return nil
        }
    }

    func base64Key() -> String? {
        if self.count != WG_KEY_LEN {
            return nil
        }
        var out = Data(repeating: 0, count: Int(WG_KEY_LEN_BASE64))
        out.withUnsafeMutableBytes { outBytes in
            self.withUnsafeBytes { inBytes in
                key_to_base64(outBytes, inBytes)
            }
        }
        out.removeLast()
        return String(data: out, encoding: .ascii)
    }

    init?(base64Key base64String: String) {
        self.init(repeating: 0, count: Int(WG_KEY_LEN))

        if !self.withUnsafeMutableBytes { key_from_base64($0, base64String) } {
            return nil
        }
    }
}
