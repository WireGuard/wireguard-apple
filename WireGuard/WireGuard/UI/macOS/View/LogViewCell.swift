// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Cocoa

class LogViewCell: NSTextField {
    init() {
        super.init(frame: .zero)
        isSelectable = false
        isEditable = false
        isBordered = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        stringValue = ""
        preferredMaxLayoutWidth = 0
    }
}

class LogViewTimestampCell: LogViewCell {
    override init() {
        super.init()
        maximumNumberOfLines = 1
        lineBreakMode = .byClipping
        preferredMaxLayoutWidth = 0
        setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        setContentHuggingPriority(.defaultLow, for: .vertical)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LogViewMessageCell: LogViewCell {
    override init() {
        super.init()
        maximumNumberOfLines = 0
        lineBreakMode = .byWordWrapping
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
