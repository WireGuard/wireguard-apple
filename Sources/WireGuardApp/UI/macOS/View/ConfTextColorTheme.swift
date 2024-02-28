// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

protocol ConfTextColorTheme {
    static var defaultColor: NSColor { get }
    static var colorMap: [UInt32: NSColor] { get }
}

struct ConfTextAquaColorTheme: ConfTextColorTheme {
    static let defaultColor = NSColor(hex: "#000000")
    static let colorMap: [UInt32: NSColor] = [
        HighlightSection.rawValue: NSColor(hex: "#326D74"), // Class name in Xcode
        HighlightField.rawValue: NSColor(hex: "#9B2393"), // Keywords in Xcode
        HighlightPublicKey.rawValue: NSColor(hex: "#643820"), // Preprocessor directives in Xcode
        HighlightPrivateKey.rawValue: NSColor(hex: "#643820"), // Preprocessor directives in Xcode
        HighlightPresharedKey.rawValue: NSColor(hex: "#643820"), // Preprocessor directives in Xcode
        HighlightIP.rawValue: NSColor(hex: "#0E0EFF"), // URLs in Xcode
        HighlightHost.rawValue: NSColor(hex: "#0E0EFF"), // URLs in Xcode
        HighlightCidr.rawValue: NSColor(hex: "#815F03"), // Attributes in Xcode
        HighlightPort.rawValue: NSColor(hex: "#815F03"), // Attributes in Xcode
        HighlightMTU.rawValue: NSColor(hex: "#1C00CF"), // Numbers in Xcode
        HighlightKeepalive.rawValue: NSColor(hex: "#1C00CF"), // Numbers in Xcode
        HighlightComment.rawValue: NSColor(hex: "#536579"), // Comments in Xcode
        HighlightError.rawValue: NSColor(hex: "#C41A16") // Strings in Xcode
    ]
}

struct ConfTextDarkAquaColorTheme: ConfTextColorTheme {
    static let defaultColor = NSColor(hex: "#FFFFFF") // Plain text in Xcode
    static let colorMap: [UInt32: NSColor] = [
        HighlightSection.rawValue: NSColor(hex: "#91D462"), // Class name in Xcode
        HighlightField.rawValue: NSColor(hex: "#FC5FA3"), // Keywords in Xcode
        HighlightPublicKey.rawValue: NSColor(hex: "#FD8F3F"), // Preprocessor directives in Xcode
        HighlightPrivateKey.rawValue: NSColor(hex: "#FD8F3F"), // Preprocessor directives in Xcode
        HighlightPresharedKey.rawValue: NSColor(hex: "#FD8F3F"), // Preprocessor directives in Xcode
        HighlightIP.rawValue: NSColor(hex: "#53A5FB"), // URLs in Xcode
        HighlightHost.rawValue: NSColor(hex: "#53A5FB"), // URLs in Xcode
        HighlightCidr.rawValue: NSColor(hex: "#75B492"), // Attributes in Xcode
        HighlightPort.rawValue: NSColor(hex: "#75B492"), // Attributes in Xcode
        HighlightMTU.rawValue: NSColor(hex: "#9686F5"), // Numbers in Xcode
        HighlightKeepalive.rawValue: NSColor(hex: "#9686F5"), // Numbers in Xcode
        HighlightComment.rawValue: NSColor(hex: "#6C7986"), // Comments in Xcode
        HighlightError.rawValue: NSColor(hex: "#FF4C4C") // Strings in Xcode
    ]
}
