// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

private let fontSize: CGFloat = 15

class ConfTextStorage: NSTextStorage {
    let defaultFont = NSFontManager.shared.convertWeight(true, of: NSFont.systemFont(ofSize: fontSize))
    private let boldFont = NSFont.boldSystemFont(ofSize: fontSize)
    private lazy var italicFont = NSFontManager.shared.convert(defaultFont, toHaveTrait: .italicFontMask)

    private var textColorTheme: ConfTextColorTheme.Type?

    private let backingStore: NSMutableAttributedString
    private(set) var hasError = false
    private(set) var privateKeyString: String?

    private(set) var hasOnePeer = false
    private(set) var lastOnePeerAllowedIPs = [String]()
    private(set) var lastOnePeerDNSServers = [String]()
    private(set) var lastOnePeerHasPublicKey = false

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

    func updateAttributes(for textColorTheme: ConfTextColorTheme.Type) {
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
        edited(.editedCharacters, range: range, changeInLength: str.utf16.count - range.length)
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

    func resetLastPeer() {
        hasOnePeer = false
        lastOnePeerAllowedIPs = []
        lastOnePeerDNSServers = []
        lastOnePeerHasPublicKey = false
    }

    func evaluateExcludePrivateIPs(highlightSpans: UnsafePointer<highlight_span>) {
        var spans = highlightSpans
        let string = backingStore.string
        enum FieldType: String {
            case dns
            case allowedips
        }
        var fieldType: FieldType?
        resetLastPeer()
        while spans.pointee.type != HighlightEnd {
            let span = spans.pointee
            var substring = String(string.substring(higlightSpan: span)).lowercased()

            if span.type == HighlightError {
                resetLastPeer()
                return
            } else if span.type == HighlightSection {
                if substring == "[peer]" {
                    if hasOnePeer {
                        resetLastPeer()
                        return
                    }
                    hasOnePeer = true
                }
            } else if span.type == HighlightField {
                fieldType = FieldType(rawValue: substring)
            } else if span.type == HighlightIP && fieldType == .dns {
                lastOnePeerDNSServers.append(substring)
            } else if span.type == HighlightIP && fieldType == .allowedips {
                let next = spans.successor()
                let nextnext = next.successor()
                if next.pointee.type == HighlightDelimiter && nextnext.pointee.type == HighlightCidr {
                    let delimiter = string.substring(higlightSpan: next.pointee)
                    let cidr = string.substring(higlightSpan: nextnext.pointee)
                    substring += delimiter + cidr
                }
                lastOnePeerAllowedIPs.append(substring)
            } else if span.type == HighlightPublicKey {
                lastOnePeerHasPublicKey = true
            }
            spans = spans.successor()
        }
    }

    func highlightSyntax() {
        guard let textColorTheme = textColorTheme else { return }
        hasError = false
        privateKeyString = nil

        let string = backingStore.string
        let fullTextRange = NSRange(..<string.endIndex, in: string)

        backingStore.beginEditing()
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColorTheme.defaultColor,
            .font: defaultFont
        ]
        backingStore.setAttributes(defaultAttributes, range: fullTextRange)
        var spans = highlight_config(string)!
        evaluateExcludePrivateIPs(highlightSpans: spans)

        let spansStart = spans
        while spans.pointee.type != HighlightEnd {
            let span = spans.pointee

            let startIndex = string.utf8.index(string.startIndex, offsetBy: span.start)
            let endIndex = string.utf8.index(startIndex, offsetBy: span.len)
            let range = NSRange(startIndex..<endIndex, in: string)

            backingStore.setAttributes(nonColorAttributes(for: span.type), range: range)

            let color = textColorTheme.colorMap[span.type.rawValue, default: textColorTheme.defaultColor]
            backingStore.addAttribute(.foregroundColor, value: color, range: range)

            if span.type == HighlightError {
                hasError = true
            }

            if span.type == HighlightPrivateKey {
                privateKeyString = String(string.substring(higlightSpan: span))
            }

            spans = spans.successor()
        }
        backingStore.endEditing()
        free(spansStart)

        beginEditing()
        edited(.editedAttributes, range: fullTextRange, changeInLength: 0)
        endEditing()
    }

}

private extension String {
    func substring(higlightSpan span: highlight_span) -> Substring {
        let startIndex = self.utf8.index(self.utf8.startIndex, offsetBy: span.start)
        let endIndex = self.utf8.index(startIndex, offsetBy: span.len)

        return self[startIndex..<endIndex]
    }
}
