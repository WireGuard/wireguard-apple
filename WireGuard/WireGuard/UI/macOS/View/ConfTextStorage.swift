// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

private let fontSize: CGFloat = 15

class ConfTextStorage: NSTextStorage {

    struct TextColorTheme {
        let plainText: NSColor
        let sections: NSColor
        let key: NSColor
        let url: NSColor
        let urlAttribute: NSColor
        let comments: NSColor
        let number: NSColor
        let error: NSColor
    }

    let defaultFont = NSFontManager.shared.convertWeight(true, of: NSFont.systemFont(ofSize: fontSize))
    private let boldFont = NSFont.boldSystemFont(ofSize: fontSize)
    private lazy var italicFont = NSFontManager.shared.convert(defaultFont, toHaveTrait: .italicFontMask)

    private var defaultAttributes: [NSAttributedString.Key: Any]! //swiftlint:disable:this implicitly_unwrapped_optional
    private var highlightAttributes: [UInt32: [NSAttributedString.Key: Any]]! //swiftlint:disable:this implicitly_unwrapped_optional

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

    func updateAttributes(for theme: TextColorTheme) {
        self.defaultAttributes = [
            .foregroundColor: theme.plainText,
            .font: defaultFont
        ]

        self.highlightAttributes = [
            HighlightSection.rawValue: [
                .foregroundColor: theme.sections,
                .font: boldFont
            ],
            HighlightKeytype.rawValue: [
                .foregroundColor: theme.key,
                .font: boldFont
            ],
            HighlightIP.rawValue: [
                .foregroundColor: theme.url,
                .font: defaultFont
            ],
            HighlightCidr.rawValue: [
                .foregroundColor: theme.urlAttribute,
                .font: defaultFont
            ],
            HighlightHost.rawValue: [
                .foregroundColor: theme.url,
                .font: defaultFont
            ],
            HighlightPort.rawValue: [
                .foregroundColor: theme.urlAttribute,
                .font: defaultFont
            ],
            HighlightMTU.rawValue: [
                .foregroundColor: theme.number,
                .font: defaultFont
            ],
            HighlightKeepalive.rawValue: [
                .foregroundColor: theme.number,
                .font: defaultFont
            ],
            HighlightComment.rawValue: [
                .foregroundColor: theme.comments,
                .font: italicFont
            ],
            HighlightDelimiter.rawValue: [
                .foregroundColor: theme.plainText,
                .font: defaultFont
            ],
            HighlightError.rawValue: [
                .foregroundColor: theme.error,
                .font: defaultFont,
                .underlineStyle: 1
            ]
        ]

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

            let attributes = self.highlightAttributes[span.type.rawValue] ?? defaultAttributes
            backingStore.setAttributes(attributes, range: NSRange(location: span.start, length: span.len))

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
