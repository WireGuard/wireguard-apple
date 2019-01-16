// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

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
        "q": #selector(NSApplication.terminate(_:))
    ]

    private var appDelegate: AppDelegate? //swiftlint:disable:this weak_delegate

    // We use a custom Application class to be able to set the app delegate
    // before app.run() gets called in NSApplicationMain().
    override init() {
        super.init()
        appDelegate = AppDelegate() // Keep a strong reference to the app delegate
        delegate = appDelegate
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
