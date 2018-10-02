//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation

extension String {

    func isBase64() -> Bool {
        let base64Predicate = NSPredicate(format: "SELF MATCHES %@", "^[a-zA-Z0-9+/]{43}=$")
        return base64Predicate.evaluate(with: self)
    }

}
