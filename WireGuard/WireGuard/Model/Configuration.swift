//
//  TunnelConfiguration.swift
//  WireGuard
//
//  Created by Roopesh Chander on 13/10/18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation

@available(OSX 10.14, iOS 12.0, *)
class TunnelConfiguration: Codable {
    var name: String
    let interface: InterfaceConfiguration
    var peers: [PeerConfiguration] = []
    init(name: String, interface: InterfaceConfiguration) {
        self.name = name
        self.interface = interface
    }
}

@available(OSX 10.14, iOS 12.0, *)
class InterfaceConfiguration: Codable {
    var privateKey: Data
    var addresses: [IPAddressRange] = []
    var listenPort: UInt64? = nil
    var mtu: UInt64? = nil
    var dns: String? = nil
    init(privateKey: Data) {
        self.privateKey = privateKey
    }
}

@available(OSX 10.14, iOS 12.0, *)
class PeerConfiguration: Codable {
    var publicKey: Data
    var preSharedKey: Data?
    var allowedIPs: [IPAddressRange] = []
    var endpoint: String?
    var persistentKeepAlive: UInt64?
    init(publicKey: Data) {
        self.publicKey = publicKey
    }
}
