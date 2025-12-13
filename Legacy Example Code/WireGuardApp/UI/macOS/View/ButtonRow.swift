// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class ButtonRow: NSView {
    let button: NSButton = {
        let button = NSButton()
        button.title = ""
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        return button
    }()

    var buttonTitle: String {
        get { return button.title }
        set(value) { button.title = value }
    }

    var isButtonEnabled: Bool {
        get { return button.isEnabled }
        set(value) { button.isEnabled = value }
    }

    var buttonToolTip: String {
        get { return button.toolTip ?? "" }
        set(value) { button.toolTip = value }
    }

    var onButtonClicked: (() -> Void)?
    var statusObservationToken: AnyObject?
    var isOnDemandEnabledObservationToken: AnyObject?
    var hasOnDemandRulesObservationToken: AnyObject?

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: button.intrinsicContentSize.height)
    }

    init() {
        super.init(frame: CGRect.zero)

        button.target = self
        button.action = #selector(buttonClicked)

        addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            button.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 155),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func buttonClicked() {
        onButtonClicked?()
    }

    override func prepareForReuse() {
        buttonTitle = ""
        buttonToolTip = ""
        onButtonClicked = nil
        statusObservationToken = nil
        isOnDemandEnabledObservationToken = nil
        hasOnDemandRulesObservationToken = nil
    }
}
