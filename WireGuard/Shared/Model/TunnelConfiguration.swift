// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation

final class TunnelConfiguration {
    var interface: InterfaceConfiguration
    let peers: [PeerConfiguration]

    static let keyLength = 32

    init(interface: InterfaceConfiguration, peers: [PeerConfiguration]) {
        self.interface = interface
        self.peers = peers

        let peerPublicKeysArray = peers.map { $0.publicKey }
        let peerPublicKeysSet = Set<Data>(peerPublicKeysArray)
        if peerPublicKeysArray.count != peerPublicKeysSet.count {
            fatalError("Two or more peers cannot have the same public key")
        }
    }
}

extension TunnelConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case interface = "Interface"
        case peers = "Peer"
    }
    
    convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let interface = try values.decode(InterfaceConfiguration.self, forKey: .interface)
        let peers = try values.decode([PeerConfiguration].self, forKey: .peers)
        self.init(interface: interface, peers: peers)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(interface, forKey: .interface)
        try container.encode(peers, forKey: .peers)
    }
}
