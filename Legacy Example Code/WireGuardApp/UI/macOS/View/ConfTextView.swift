// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class ConfTextView: NSTextView {

    private let confTextStorage = ConfTextStorage()

    @objc dynamic var hasError = false
    @objc dynamic var privateKeyString: String?
    @objc dynamic var singlePeerAllowedIPs: [String]?

    override var string: String {
        didSet {
            confTextStorage.highlightSyntax()
            updateConfigData()
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
            confTextStorage.updateAttributes(for: ConfTextDarkAquaColorTheme.self)
        default:
            confTextStorage.updateAttributes(for: ConfTextAquaColorTheme.self)
        }
    }

    private func updateConfigData() {
        if hasError != confTextStorage.hasError {
            hasError = confTextStorage.hasError
        }
        if privateKeyString != confTextStorage.privateKeyString {
            privateKeyString = confTextStorage.privateKeyString
        }
        let hasSyntaxError = confTextStorage.hasError
        let hasSemanticError = confTextStorage.privateKeyString == nil || !confTextStorage.lastOnePeerHasPublicKey
        let updatedSinglePeerAllowedIPs = confTextStorage.hasOnePeer && !hasSyntaxError && !hasSemanticError ? confTextStorage.lastOnePeerAllowedIPs : nil
        if singlePeerAllowedIPs != updatedSinglePeerAllowedIPs {
            singlePeerAllowedIPs = updatedSinglePeerAllowedIPs
        }
    }

    func setConfText(_ text: String) {
        let fullTextRange = NSRange(..<string.endIndex, in: string)
        if shouldChangeText(in: fullTextRange, replacementString: text) {
            replaceCharacters(in: fullTextRange, with: text)
            didChangeText()
        }
    }
}

extension ConfTextView: NSTextViewDelegate {

    func textDidChange(_ notification: Notification) {
        confTextStorage.highlightSyntax()
        updateConfigData()
        needsDisplay = true
    }

}
