// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

class ConfTextView: NSTextView {

    private let confTextStorage = ConfTextStorage()

    var hasError: Bool { return confTextStorage.hasError }

    override var string: String {
        didSet {
            confTextStorage.highlightSyntax()
        }
    }

    init() {
        let textContainer = NSTextContainer()
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        confTextStorage.addLayoutManager(layoutManager)
        super.init(frame: CGRect(x: 0, y: 0, width: 1, height: 60), textContainer: textContainer)
        font = confTextStorage.defaultFont
        updateTheme()
        delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        updateTheme()
    }

    private func updateTheme() {
        let theme: ConfTextStorage.TextColorTheme
        switch effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua {
        case .darkAqua:
            theme = ConfTextStorage.TextColorTheme(black: NSColor(hex: "#c7c7c7"), red: NSColor(hex: "#dc322f"), green: NSColor(hex: "#859900"), yellow: NSColor(hex: "#c7c400"), blue: NSColor(hex: "#268bd2"), magenta: NSColor(hex: "#d33682"), cyan: NSColor(hex: "#2aa198"), white: NSColor(hex: "#383838"), default: NSColor(hex: "#c7c7c7"))
        default:
            theme = ConfTextStorage.TextColorTheme(black: NSColor(hex: "#000000"), red: NSColor(hex: "#c91b00"), green: NSColor(hex: "#00c200"), yellow: NSColor(hex: "#c7c400"), blue: NSColor(hex: "#0225c7"), magenta: NSColor(hex: "#c930c7"), cyan: NSColor(hex: "#00c5c7"), white: NSColor(hex: "#c7c7c7"), default: NSColor(hex: "#000000"))
        }
        confTextStorage.updateAttributes(for: theme)
    }

}

extension ConfTextView: NSTextViewDelegate {

    func textDidChange(_ notification: Notification) {
        confTextStorage.highlightSyntax()
        needsDisplay = true
    }

}
