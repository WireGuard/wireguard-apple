//
//  Interface+Extension.swift
//  WireGuard
//
//  Created by Eric Kuck on 8/15/18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import Foundation

extension Interface {

    func validate() throws {
        guard let privateKey = privateKey, !privateKey.isEmpty else {
            throw InterfaceValidationError.emptyPrivateKey
        }

        guard privateKey.isBase64() else {
            throw InterfaceValidationError.invalidPrivateKey
        }

        try? addresses?.commaSeparatedToArray().forEach { address in
            do {
                try _ = CIDRAddress(stringRepresentation: address)
            } catch {
                throw InterfaceValidationError.invalidAddress(cause: error)
            }
        }

        try? dns?.commaSeparatedToArray().forEach { address in
            do {
                try _ = Endpoint(endpointString: address)
            } catch {
                throw InterfaceValidationError.invalidDNSServer(cause: error)
            }
        }
    }

}

enum InterfaceValidationError: Error {
    case emptyPrivateKey
    case invalidPrivateKey
    case invalidAddress(cause: Error)
    case invalidDNSServer(cause: Error)
}
