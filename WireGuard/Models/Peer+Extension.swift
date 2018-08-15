//
//  Peer+Extension.swift
//  WireGuard
//
//  Created by Eric Kuck on 8/15/18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import Foundation

extension Peer {

    func validate() throws {
        guard let publicKey = publicKey, !publicKey.isEmpty else {
            throw PeerValidationError.emptyPublicKey
        }

        guard publicKey.isBase64() else {
            throw PeerValidationError.invalidPublicKey
        }

        guard let allowedIPs = allowedIPs, !allowedIPs.isEmpty else {
            throw PeerValidationError.nilAllowedIps
        }

        try allowedIPs.commaSeparatedToArray().forEach { address in
            do {
                try _ = CIDRAddress(stringRepresentation: address)
            } catch {
                throw PeerValidationError.invalidAllowedIPs(cause: error)
            }
        }

        if let endpoint = endpoint {
            do {
                try _ = Endpoint(endpointString: endpoint)
            } catch {
                throw PeerValidationError.invalidEndpoint(cause: error)
            }
        }

        guard persistentKeepalive >= 0, persistentKeepalive <= 65535 else {
            throw PeerValidationError.invalidPersistedKeepAlive
        }
    }

}

enum PeerValidationError: Error {
    case emptyPublicKey
    case invalidPublicKey
    case nilAllowedIps
    case invalidAllowedIPs(cause: Error)
    case invalidEndpoint(cause: Error)
    case invalidPersistedKeepAlive
}
