// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import Foundation

@available(OSX 10.14, iOS 12.0, *)
class TunnelConfiguration: Codable {
    var interface: InterfaceConfiguration
    var peers: [PeerConfiguration] = []
    init(interface: InterfaceConfiguration) {
        self.interface = interface
    }
}

@available(OSX 10.14, iOS 12.0, *)
struct InterfaceConfiguration: Codable {
    var name: String
    var privateKey: Data
    var addresses: [IPAddressRange] = []
    var listenPort: UInt16? = nil
    var mtu: UInt16? = nil
    var dns: [DNSServer] = []

    var publicKey: Data {
        return Curve25519.generatePublicKey(fromPrivateKey: privateKey)
    }

    init(name: String, privateKey: Data) {
        self.name = name
        self.privateKey = privateKey
        if (privateKey.count != 32) { fatalError("Invalid private key") }
    }
}

@available(OSX 10.14, iOS 12.0, *)
struct PeerConfiguration: Codable {
    var publicKey: Data
    var preSharedKey: Data? {
        didSet(value) {
            if let value = value {
                if (value.count != 32) { fatalError("Invalid pre-shared key") }
            }
        }
    }
    var allowedIPs: [IPAddressRange] = []
    var endpoint: Endpoint?
    var persistentKeepAlive: UInt16?

    init(publicKey: Data) {
        self.publicKey = publicKey
        if (publicKey.count != 32) { fatalError("Invalid public key") }
    }
}
