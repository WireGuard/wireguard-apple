// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class LogViewCell: NSTableCellView {
    var text: String = "" {
        didSet { textField?.stringValue = text }
    }

    init() {
        super.init(frame: .zero)

        let textField = NSTextField(wrappingLabelWithString: "")
        addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            textField.topAnchor.constraint(equalTo: self.topAnchor),
            textField.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])

        self.textField = textField
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        textField?.stringValue = ""
    }
}

class LogViewTimestampCell: LogViewCell {
    override init() {
        super.init()
        if let textField = textField {
            textField.maximumNumberOfLines = 1
            textField.lineBreakMode = .byClipping
            textField.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
            textField.setContentHuggingPriority(.defaultLow, for: .vertical)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LogViewMessageCell: LogViewCell {
    override init() {
        super.init()
        if let textField = textField {
            textField.maximumNumberOfLines = 0
            textField.lineBreakMode = .byWordWrapping
            textField.setContentCompressionResistancePriority(.required, for: .vertical)
            textField.setContentHuggingPriority(.required, for: .vertical)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
