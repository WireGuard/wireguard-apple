// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Cocoa

class Application: NSApplication {

    private let characterKeyCommands = [
        "x": #selector(NSText.cut(_:)),
        "c": #selector(NSText.copy(_:)),
        "v": #selector(NSText.paste(_:)),
        "z": #selector(UndoActionRespondable.undo(_:)),
        "a": #selector(NSResponder.selectAll(_:)),
        "Z": #selector(UndoActionRespondable.redo(_:)),
        "w": #selector(NSWindow.performClose(_:)),
        "m": #selector(NSWindow.performMiniaturize(_:)),
        "q": #selector(AppDelegate.quit)
    ]

    private var appDelegate: AppDelegate? //swiftlint:disable:this weak_delegate

    override init() {
        super.init()
        appDelegate = AppDelegate() // Keep a strong reference to the app delegate
        delegate = appDelegate // Set delegate before app.run() gets called in NSApplicationMain()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sendEvent(_ event: NSEvent) {
        let modifierFlags = event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue

        if event.type == .keyDown,
            (modifierFlags == NSEvent.ModifierFlags.command.rawValue || modifierFlags == NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
            let selector = characterKeyCommands[event.charactersIgnoringModifiers ?? ""] {
            sendAction(selector, to: nil, from: self)
        } else {
            super.sendEvent(event)
        }
    }
}

@objc protocol UndoActionRespondable {
    func undo(_ sender: AnyObject)
    func redo(_ sender: AnyObject)
}
