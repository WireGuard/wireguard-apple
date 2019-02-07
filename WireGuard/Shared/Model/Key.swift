// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation

extension Data {
    func isKey() -> Bool {
        return self.count == 32
    }

    func hexKey() -> String? {
        if self.count != 32 {
            return nil
        }
        var nibble1, nibble2: UInt
        var hex: [UInt8] = Array(repeating: 0, count: 64)

        for i in 0..<32 {
            let n = UInt(self[i])
            nibble1 = 87 + (n >> 4)
            nibble1 += (((UInt(bitPattern: Int(n >> 4) - 10)) >> 8) & 217)
            nibble2 = 87 + (n & 0xf)
            nibble2 += (((UInt(bitPattern: Int(n & 0xf) - 10)) >> 8) & 217)
            hex[i * 2] = UInt8(truncatingIfNeeded: nibble1)
            hex[i * 2 + 1] = UInt8(truncatingIfNeeded: nibble2)
        }
        return String(bytes: hex, encoding: .ascii)
    }

    private func decodeHex(c: UInt8) -> (UInt8, UInt8) {
        var alpha0, alpha, num0, num, val, ret: UInt8

        num = c ^ 48
        num0 = UInt8(truncatingIfNeeded: UInt(bitPattern: Int(num) - 10) >> 8)

        alpha = UInt8(truncatingIfNeeded: Int(c & 223) - 55)
        alpha0 = UInt8(truncatingIfNeeded: (UInt(bitPattern: Int(alpha) - 10) ^ UInt(bitPattern: Int(alpha) - 16)) >> 8)

        ret = UInt8(truncatingIfNeeded: UInt(bitPattern: Int(num0 | alpha0) - 1) >> 8)
        val = (num0 & num) | (alpha0 & alpha)

        return (val, ret)
    }

    init?(hexKey hexString: String) {
        let hex = [UInt8](hexString.utf8)
        if hex.count != 64 {
            return nil
        }
        self.init(repeating: 0, count: 32)

        var ret: UInt8 = 0
        for i in stride(from: 0, to: 64, by: 2) {
            var v1, v2, r: UInt8

            (v1, r) = decodeHex(c: hex[i])
            ret |= r

            (v2, r) = decodeHex(c: hex[i + 1])
            ret |= r

            self[i / 2] = (v1 << 4) | v2
        }

        if 1 & (UInt8(truncatingIfNeeded: Int(ret) - 1) >> 8) != 0 {
            return nil
        }
    }


    private func encodeBase64<T: RandomAccessCollection>(dest: inout ArraySlice<UInt8>, src: T) where T.Index == Int, T.Element == UInt8 {
        let a = Int((src[src.startIndex + 0] >> 2) & 63)
        let b = Int(((src[src.startIndex + 0] << 4) | (src[src.startIndex + 1] >> 4)) & 63)
        let c = Int(((src[src.startIndex + 1] << 2) | (src[src.startIndex + 2] >> 6)) & 63)
        let d = Int(src[src.startIndex + 2] & 63)

        for (i, x) in [a, b, c, d].enumerated() {
            var y: Int = x + 65
            y += ((25 - x) >> 8) & 6
            y -= ((51 - x) >> 8) & 75
            y -= ((61 - x) >> 8) & 15
            y += ((62 - x) >> 8) & 3
            dest[dest.startIndex + i] = UInt8(y)
        }
    }

    func base64Key() -> String? {
        if self.count != 32 {
            return nil
        }
        var base64: [UInt8] = Array(repeating: 0, count: 44)

        for i in 0..<(32 / 3) {
            encodeBase64(dest: &base64[(i * 4)..<(i * 4 + 4)], src: self[(i * 3)..<(i * 3 + 3)])
        }
        encodeBase64(dest: &base64[40..<44], src: [self[30], self[31], 0])
        base64[43] = 61

        return String(bytes: base64, encoding: .ascii)
    }

    private func decodeBase64<T: RandomAccessCollection>(src: T) -> Int where T.Index == Int, T.Element == UInt8 {
        var val: Int = 0
        for i in 0..<4 {
            let n = Int(src[src.startIndex + i])
            var a: Int = -1
            var b: Int
            b = ((((65 - 1) - n) & (n - (90 + 1))) >> 8)
            a += b & (n - 64)
            b = ((((97 - 1) - n) & (n - (122 + 1))) >> 8)
            a += b & (n - 70)
            b = ((((48 - 1) - n) & (n - (57 + 1))) >> 8)
            a += b & (n + 5)
            b = ((((43 - 1) - n) & (n - (43 + 1))) >> 8)
            a += b & 63
            b = ((((47 - 1) - n) & (n - (47 + 1))) >> 8)
            a += b & 64
            val |= a << (18 - 6 * i)
        }
        return val
    }

    init?(base64Key base64String: String) {
        let base64 = [UInt8](base64String.utf8)
        if base64.count != 44 || base64[43] != 61 {
            return nil
        }
        self.init(repeating: 0, count: 32)

        var ret: UInt8 = 0
        var val: Int
        for i in 0..<(32/3) {
            val = decodeBase64(src: base64[(i * 4)..<(i * 4 + 4)])
            ret |= UInt8(UInt32(val) >> UInt32(31))
            self[i * 3 + 0] = UInt8((val >> 16) & 0xff)
            self[i * 3 + 1] = UInt8((val >> 8) & 0xff)
            self[i * 3 + 2] = UInt8(val & 0xff)
        }
        val = decodeBase64(src: [base64[40], base64[41], base64[42], 65])
        ret |= UInt8((UInt32(val) >> 31) | UInt32(val & 0xff))
        self[30] = UInt8((val >> 16) & 0xff)
        self[31] = UInt8((val >> 8) & 0xff)

        if 1 & (UInt8(truncatingIfNeeded: Int(ret) - 1) >> 8) != 0 {
            return nil
        }
    }
}
