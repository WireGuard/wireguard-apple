// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

var appDelegate: AppDelegate?

class Application: NSApplication {
    // We use a custom Application class to be able to set the app delegate
    // before app.run() gets called in NSApplicationMain().
    override class var shared: NSApplication {
        let app = NSApplication.shared
        appDelegate = AppDelegate() // Keep a strong reference to the app delegate
        app.delegate = appDelegate
        return app
    }
}
