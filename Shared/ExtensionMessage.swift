//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import Foundation

public class ExtensionMessage: Equatable {

    public static let requestVersion = ExtensionMessage(0xff)

    public let data: Data

    private init(_ byte: UInt8) {
        data = Data(bytes: [byte])
    }

    init(_ data: Data) {
        self.data = data
    }

    // MARK: Equatable
    public static func == (lhs: ExtensionMessage, rhs: ExtensionMessage) -> Bool {
        return (lhs.data == rhs.data)
    }
}
