// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

class ConfTextView: NSTextView {

    private let confTextStorage = ConfTextStorage()

    var hasError: Bool { return confTextStorage.hasError }
    @objc dynamic var privateKeyString: String?

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
        allowsUndo = true
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
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
            theme = ConfTextStorage.TextColorTheme(plainText: NSColor(hex: "#FFFFFF"), sections: NSColor(hex: "#91D462"), keyType: NSColor(hex: "#FC5FA3"), key: NSColor(hex: "#FD8F3F"), url: NSColor(hex: "#53A5FB"), urlAttribute: NSColor(hex: "#75B492"), comments: NSColor(hex: "#6C7986"), number: NSColor(hex: "#9686F5"), error: NSColor(hex: "#FF4C4C"))
        default:
            theme = ConfTextStorage.TextColorTheme(plainText: NSColor(hex: "#000000"), sections: NSColor(hex: "#326D74"), keyType: NSColor(hex: "#9B2393"), key: NSColor(hex: "#643820"), url: NSColor(hex: "#0E0EFF"), urlAttribute: NSColor(hex: "#815F03"), comments: NSColor(hex: "#536579"), number: NSColor(hex: "#1C00CF"), error: NSColor(hex: "#C41A16"))
        }
        confTextStorage.updateAttributes(for: theme)
    }

}

extension ConfTextView: NSTextViewDelegate {

    func textDidChange(_ notification: Notification) {
        confTextStorage.highlightSyntax()
        if privateKeyString != confTextStorage.privateKeyString {
            privateKeyString = confTextStorage.privateKeyString
        }
        needsDisplay = true
    }

}
