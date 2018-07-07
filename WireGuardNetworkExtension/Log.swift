//
//  Log.swift
//  WireGuardNetworkExtension
//
//  Created by Jeroen Leenarts on 07-07-18.
//  Copyright © 2018 WireGuard. All rights reserved.
//

import os.log

struct Log {
    static var general = OSLog(subsystem: "com.wireguard.ios.WireGuard.WireGuardNetworkExtension", category: "general")
}
