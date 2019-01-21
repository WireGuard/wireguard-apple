// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Cocoa

protocol ConfTextColorTheme {
    var defaultColor: NSColor { get }

    func color(for: highlight_type) -> NSColor
}

struct ConfTextAquaColorTheme: ConfTextColorTheme {
    var defaultColor: NSColor {
        return NSColor(hex: "#000000") // Plain text in Xcode
    }

    func color(for highlightType: highlight_type) -> NSColor {
        switch highlightType.rawValue {
        case HighlightSection.rawValue:
            return NSColor(hex: "#326D74") // Class name in Xcode
        case HighlightField.rawValue:
            return NSColor(hex: "#9B2393") // Keywords in Xcode
        case HighlightPublicKey.rawValue, HighlightPrivateKey.rawValue, HighlightPresharedKey.rawValue:
            return NSColor(hex: "#643820") // Preprocessor directives in Xcode
        case HighlightIP.rawValue, HighlightHost.rawValue:
            return NSColor(hex: "#0E0EFF") // URLs in Xcode
        case HighlightCidr.rawValue, HighlightPort.rawValue:
            return NSColor(hex: "#815F03") // Attributes in Xcode
        case HighlightMTU.rawValue, HighlightKeepalive.rawValue:
            return NSColor(hex: "#1C00CF") // Numbers in Xcode
        case HighlightComment.rawValue:
            return NSColor(hex: "#536579") // Comments in Xcode
        case HighlightError.rawValue:
            return NSColor(hex: "#C41A16") // Strings in Xcode
        default:
            return defaultColor
        }
    }
}

struct ConfTextDarkAquaColorTheme: ConfTextColorTheme {
    var defaultColor: NSColor {
        return NSColor(hex: "#FFFFFF") // Plain text in Xcode
    }

    func color(for highlightType: highlight_type) -> NSColor {
        switch highlightType.rawValue {
        case HighlightSection.rawValue:
            return NSColor(hex: "#91D462") // Class name in Xcode
        case HighlightField.rawValue:
            return NSColor(hex: "#FC5FA3") // Keywords in Xcode
        case HighlightPublicKey.rawValue, HighlightPrivateKey.rawValue, HighlightPresharedKey.rawValue:
            return NSColor(hex: "#FD8F3F") // Preprocessor directives in Xcode
        case HighlightIP.rawValue, HighlightHost.rawValue:
            return NSColor(hex: "#53A5FB") // URLs in Xcode
        case HighlightCidr.rawValue, HighlightPort.rawValue:
            return NSColor(hex: "#75B492") // Attributes in Xcode
        case HighlightMTU.rawValue, HighlightKeepalive.rawValue:
            return NSColor(hex: "#9686F5") // Numbers in Xcode
        case HighlightComment.rawValue:
            return NSColor(hex: "#6C7986") // Comments in Xcode
        case HighlightError.rawValue:
            return NSColor(hex: "#FF4C4C") // Strings in Xcode
        default:
            return defaultColor
        }
    }
}
