// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

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
        switch effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua {
        case .darkAqua:
            confTextStorage.updateAttributes(for: ConfTextDarkAquaColorTheme())
        default:
            confTextStorage.updateAttributes(for: ConfTextAquaColorTheme())
        }
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
