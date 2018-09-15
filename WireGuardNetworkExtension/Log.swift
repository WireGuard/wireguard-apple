//
//  Log.swift
//  WireGuardNetworkExtension
//
//  Created by Jeroen Leenarts on 07-07-18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//

import os.log

struct Log {
    static var general = OSLog(subsystem: "com.wireguard.ios.network-extension", category: "general")
}
