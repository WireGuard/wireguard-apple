// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Cocoa

private let fontSize: CGFloat = 15

class ConfTextStorage: NSTextStorage {

    let defaultFont = NSFontManager.shared.convertWeight(true, of: NSFont.systemFont(ofSize: fontSize))
    private let boldFont = NSFont.boldSystemFont(ofSize: fontSize)
    private lazy var italicFont = NSFontManager.shared.convert(defaultFont, toHaveTrait: .italicFontMask)

    private var textColorTheme: ConfTextColorTheme?

    private let backingStore: NSMutableAttributedString
    private(set) var hasError = false
    private(set) var privateKeyString: String?

    override init() {
        backingStore = NSMutableAttributedString(string: "")
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }

    func nonColorAttributes(for highlightType: highlight_type) -> [NSAttributedString.Key: Any] {
        switch highlightType.rawValue {
        case HighlightSection.rawValue, HighlightField.rawValue:
            return [.font: boldFont]
        case HighlightPublicKey.rawValue, HighlightPrivateKey.rawValue, HighlightPresharedKey.rawValue,
             HighlightIP.rawValue, HighlightCidr.rawValue, HighlightHost.rawValue, HighlightPort.rawValue,
             HighlightMTU.rawValue, HighlightKeepalive.rawValue, HighlightDelimiter.rawValue:
            return [.font: defaultFont]
        case HighlightComment.rawValue:
            return [.font: italicFont]
        case HighlightError.rawValue:
            return [.font: defaultFont, .underlineStyle: 1]
        default:
            return [:]
        }
    }

    func updateAttributes(for textColorTheme: ConfTextColorTheme) {
        self.textColorTheme = textColorTheme
        highlightSyntax()
    }

    override var string: String {
        return backingStore.string
    }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
    }

    override func replaceCharacters(in range: NSRange, with attrString: NSAttributedString) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: attrString)
        edited(.editedCharacters, range: range, changeInLength: attrString.length - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    func highlightSyntax() {
        hasError = false
        privateKeyString = nil

        backingStore.beginEditing()
        var spans = highlight_config(backingStore.string.cString(using: String.Encoding.utf8))!

        while spans.pointee.type != HighlightEnd {
            let span = spans.pointee

            let range = NSRange(location: span.start, length: span.len)
            backingStore.setAttributes(nonColorAttributes(for: span.type), range: range)
            if let textColorTheme = textColorTheme {
                let color = textColorTheme.color(for: span.type)
                backingStore.addAttribute(.foregroundColor, value: color, range: range)
            }

            if span.type == HighlightError {
                hasError = true
            }

            if span.type == HighlightPrivateKey {
                privateKeyString = backingStore.attributedSubstring(from: NSRange(location: span.start, length: span.len)).string
            }

            spans = spans.successor()
        }
        backingStore.endEditing()

        beginEditing()
        edited(.editedAttributes, range: NSRange(location: 0, length: (backingStore.string as NSString).length), changeInLength: 0)
        endEditing()
    }

}
