//
//  Copyright © 2018 WireGuard LLC. All Rights Reserved.
//

import os.log

struct Log {
    static var general = OSLog(subsystem: "com.wireguard.ios.network-extension", category: "general")
}
