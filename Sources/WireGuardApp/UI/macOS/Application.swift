// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class Application: NSApplication {

    private var appDelegate: AppDelegate? // swiftlint:disable:this weak_delegate

    override init() {
        super.init()
        appDelegate = AppDelegate() // Keep a strong reference to the app delegate
        delegate = appDelegate // Set delegate before app.run() gets called in NSApplicationMain()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
