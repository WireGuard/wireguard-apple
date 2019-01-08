// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

class PopupRow: NSView {
    let keyLabel: NSTextField = {
        let keyLabel = NSTextField()
        keyLabel.isEditable = false
        keyLabel.isSelectable = false
        keyLabel.isBordered = false
        keyLabel.alignment = .right
        keyLabel.maximumNumberOfLines = 1
        keyLabel.lineBreakMode = .byTruncatingTail
        keyLabel.backgroundColor = .clear
        return keyLabel
    }()

    let valuePopup = NSPopUpButton()

    var key: String {
        get { return keyLabel.stringValue }
        set(value) { keyLabel.stringValue = value }
    }

    var valueOptions: [String] {
        get { return valuePopup.itemTitles }
        set(value) {
            valuePopup.removeAllItems()
            valuePopup.addItems(withTitles: value)
        }
    }

    var selectedOptionIndex: Int {
        get { return valuePopup.indexOfSelectedItem }
        set(value) { valuePopup.selectItem(at: value) }
    }

    override var intrinsicContentSize: NSSize {
        let height = max(keyLabel.intrinsicContentSize.height, valuePopup.intrinsicContentSize.height)
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    init() {
        super.init(frame: CGRect.zero)

        addSubview(keyLabel)
        addSubview(valuePopup)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        valuePopup.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            keyLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            keyLabel.firstBaselineAnchor.constraint(equalTo: valuePopup.firstBaselineAnchor),
            self.leadingAnchor.constraint(equalTo: keyLabel.leadingAnchor),
            keyLabel.trailingAnchor.constraint(equalTo: valuePopup.leadingAnchor, constant: -5)
        ])

        keyLabel.setContentCompressionResistancePriority(.defaultHigh + 2, for: .horizontal)
        keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let widthConstraint = keyLabel.widthAnchor.constraint(equalToConstant: 150)
        widthConstraint.priority = .defaultHigh + 1
        widthConstraint.isActive = true
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        key = ""
        valueOptions = []
    }
}
