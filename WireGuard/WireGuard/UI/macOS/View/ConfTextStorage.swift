// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

class ConfTextStorage: NSTextStorage {

    struct TextColorTheme {
        let black: NSColor
        let red: NSColor
        let green: NSColor
        let yellow: NSColor
        let blue: NSColor
        let magenta: NSColor
        let cyan: NSColor
        let white: NSColor
        let `default`: NSColor
    }

    let defaultFont = NSFont.systemFont(ofSize: 16)
    private let boldFont = NSFont.boldSystemFont(ofSize: 16)

    private var defaultAttributes: [NSAttributedString.Key: Any]! //swiftlint:disable:this implicitly_unwrapped_optional
    private var highlightAttributes: [UInt32: [NSAttributedString.Key: Any]]! //swiftlint:disable:this implicitly_unwrapped_optional

    private let backingStore: NSMutableAttributedString
    private(set) var hasError = false

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

    //swiftlint:disable:next function_body_length
    func updateAttributes(for theme: TextColorTheme) {
        self.defaultAttributes = [
            .foregroundColor: theme.default,
            .font: defaultFont
        ]

        self.highlightAttributes = [
            HighlightSection.rawValue: [
                .foregroundColor: theme.black,
                .font: boldFont
            ],
            HighlightKeytype.rawValue: [
                .foregroundColor: theme.blue,
                .font: boldFont
            ],
            HighlightKey.rawValue: [
                .foregroundColor: theme.yellow,
                .font: boldFont
            ],
            HighlightCmd.rawValue: [
                .foregroundColor: theme.white,
                .font: defaultFont
            ],
            HighlightIP.rawValue: [
                .foregroundColor: theme.green,
                .font: defaultFont
            ],
            HighlightCidr.rawValue: [
                .foregroundColor: theme.yellow,
                .font: defaultFont
            ],
            HighlightHost.rawValue: [
                .foregroundColor: theme.green,
                .font: boldFont
            ],
            HighlightPort.rawValue: [
                .foregroundColor: theme.magenta,
                .font: defaultFont
            ],
            HighlightTable.rawValue: [
                .foregroundColor: theme.blue,
                .font: defaultFont
            ],
            HighlightFwMark.rawValue: [
                .foregroundColor: theme.blue,
                .font: defaultFont
            ],
            HighlightMTU.rawValue: [
                .foregroundColor: theme.blue,
                .font: defaultFont
            ],
            HighlightSaveConfig.rawValue: [
                .foregroundColor: theme.blue,
                .font: defaultFont
            ],
            HighlightKeepalive.rawValue: [
                .foregroundColor: theme.blue,
                .font: defaultFont
            ],
            HighlightComment.rawValue: [
                .foregroundColor: theme.cyan,
                .font: defaultFont
            ],
            HighlightDelimiter.rawValue: [
                .foregroundColor: theme.cyan,
                .font: defaultFont
            ],
            HighlightError.rawValue: [
                .foregroundColor: theme.red,
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

        backingStore.beginEditing()
        var spans = highlight_config(backingStore.string.cString(using: String.Encoding.utf8))!

        while spans.pointee.type != HighlightEnd {
            let span = spans.pointee

            let attributes = self.highlightAttributes[span.type.rawValue] ?? defaultAttributes
            backingStore.setAttributes(attributes, range: NSRange(location: span.start, length: span.len))

            if span.type == HighlightError {
                hasError = true
            }

            spans = spans.successor()
        }
        backingStore.endEditing()

        beginEditing()
        edited(.editedAttributes, range: NSRange(location: 0, length: (backingStore.string as NSString).length), changeInLength: 0)
        endEditing()
    }

}
