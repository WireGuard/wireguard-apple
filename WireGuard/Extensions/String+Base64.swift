//
//  String+Base64.swift
//  WireGuard
//
//  Created by Eric Kuck on 8/15/18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import Foundation

extension String {

    func isBase64() -> Bool {
        let base64Predicate = NSPredicate(format: "SELF MATCHES %@", "^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{4}|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{2}==)$")
        return base64Predicate.evaluate(with: self)
    }

}
