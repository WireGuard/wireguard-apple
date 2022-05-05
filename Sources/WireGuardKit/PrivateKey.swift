// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Foundation

#if SWIFT_PACKAGE
import WireGuardKitC
#endif

/// Umbrella protocol for all kinds of keys.
public protocol WireGuardKey: RawRepresentable, Hashable, Codable where RawValue == Data {}

/// Class describing a private key used by WireGuard.
public final class PrivateKey: WireGuardKey {
    public let rawValue: Data

    /// Initialize the key with existing raw representation
    public init?(rawValue: Data) {
        if rawValue.count == WG_KEY_LEN {
            self.rawValue = rawValue
        } else {
            return nil
        }
    }

    /// Initialize new private key
    convenience public init() {
        var privateKeyData = Data(repeating: 0, count: Int(WG_KEY_LEN))
        privateKeyData.withUnsafeMutableBytes { (rawBufferPointer: UnsafeMutableRawBufferPointer) in
            let privateKeyBytes = rawBufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            curve25519_generate_private_key(privateKeyBytes)
        }
        self.init(rawValue: privateKeyData)!
    }

    /// Derived public key
    public var publicKey: PublicKey {
        return rawValue.withUnsafeBytes { (privateKeyBufferPointer: UnsafeRawBufferPointer) -> PublicKey in
            var publicKeyData = Data(repeating: 0, count: Int(WG_KEY_LEN))
            let privateKeyBytes = privateKeyBufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self)

            publicKeyData.withUnsafeMutableBytes { (publicKeyBufferPointer: UnsafeMutableRawBufferPointer) in
                let publicKeyBytes = publicKeyBufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                curve25519_derive_public_key(publicKeyBytes, privateKeyBytes)
            }

            return PublicKey(rawValue: publicKeyData)!
        }
    }
}

/// Class describing a public key used by WireGuard.
public final class PublicKey: WireGuardKey {
    public let rawValue: Data

    /// Initialize the key with existing raw representation
    public init?(rawValue: Data) {
        if rawValue.count == WG_KEY_LEN {
            self.rawValue = rawValue
        } else {
            return nil
        }
    }
}

/// Class describing a pre-shared key used by WireGuard.
public final class PreSharedKey: WireGuardKey {
    public let rawValue: Data

    /// Initialize the key with existing raw representation
    public init?(rawValue: Data) {
        if rawValue.count == WG_KEY_LEN {
            self.rawValue = rawValue
        } else {
            return nil
        }
    }
}

// Default implementation
extension WireGuardKey {
    /// Hex encoded representation
    public var hexKey: String {
        return rawValue.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) -> String in
            let inBytes = rawBufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            var outBytes = [CChar](repeating: 0, count: Int(WG_KEY_LEN_HEX))
            key_to_hex(&outBytes, inBytes)
            return String(cString: outBytes, encoding: .ascii)!
        }
    }

    /// Base64 encoded representation
    public var base64Key: String {
        return rawValue.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) -> String in
            let inBytes = rawBufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            var outBytes = [CChar](repeating: 0, count: Int(WG_KEY_LEN_BASE64))
            key_to_base64(&outBytes, inBytes)
            return String(cString: outBytes, encoding: .ascii)!
        }
    }

    /// Initialize the key with hex representation
    public init?(hexKey: String) {
        var bytes = Data(repeating: 0, count: Int(WG_KEY_LEN))
        let success = bytes.withUnsafeMutableBytes { (bufferPointer: UnsafeMutableRawBufferPointer) -> Bool in
            return key_from_hex(bufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self), hexKey)
        }
        if success {
            self.init(rawValue: bytes)
        } else {
            return nil
        }
    }

    /// Initialize the key with base64 representation
    public init?(base64Key: String) {
        var bytes = Data(repeating: 0, count: Int(WG_KEY_LEN))
        let success = bytes.withUnsafeMutableBytes { (bufferPointer: UnsafeMutableRawBufferPointer) -> Bool in
            return key_from_base64(bufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self), base64Key)
        }
        if success {
            self.init(rawValue: bytes)
        } else {
            return nil
        }
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)

        if let instance = Self.init(rawValue: data) {
            self = instance
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Corrupt key data."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        try container.encode(rawValue)
    }

    // MARK: - Equatable

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue.withUnsafeBytes { (lhsBytes: UnsafeRawBufferPointer) -> Bool in
            return rhs.rawValue.withUnsafeBytes { (rhsBytes: UnsafeRawBufferPointer) -> Bool in
                return key_eq(
                    lhsBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    rhsBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                )
            }
        }
    }
}
