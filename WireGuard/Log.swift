//
//  Log.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 07-07-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import os.log

struct Log {
    static var general = OSLog(subsystem: "com.wireguard.ios.WireGuard", category: "general")
}
