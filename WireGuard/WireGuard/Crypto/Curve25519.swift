// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

struct Curve25519 {
    static func generatePrivateKey() -> Data {
        var privateKey = Data(repeating: 0, count: 32)
        privateKey.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
            curve25519_generate_private_key(bytes)
        }
        assert(privateKey.count == 32)
        return privateKey
    }

    static func generatePublicKey(fromPrivateKey privateKey: Data) -> Data {
        assert(privateKey.count == 32)
        var publicKey = Data(repeating: 0, count: 32)
        privateKey.withUnsafeBytes { (privateKeyBytes: UnsafePointer<UInt8>) in
            publicKey.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
                curve25519_derive_public_key(bytes, privateKeyBytes)
            }
        }
        assert(publicKey.count == 32)
        return publicKey
    }
}

extension InterfaceConfiguration {
    var publicKey: Data {
        return Curve25519.generatePublicKey(fromPrivateKey: privateKey)
    }
}
