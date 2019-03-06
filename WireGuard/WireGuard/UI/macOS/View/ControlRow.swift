// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Cocoa

class ControlRow: NSView {
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

    var key: String {
        get { return keyLabel.stringValue }
        set(value) { keyLabel.stringValue = value }
    }

    override var intrinsicContentSize: NSSize {
        let height = max(keyLabel.intrinsicContentSize.height, controlView.intrinsicContentSize.height)
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    let controlView: NSView

    init(controlView: NSView) {
        self.controlView = controlView
        super.init(frame: CGRect.zero)

        addSubview(keyLabel)
        addSubview(controlView)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        controlView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            keyLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.leadingAnchor.constraint(equalTo: keyLabel.leadingAnchor),
            keyLabel.trailingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: -5)
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
    }
}
