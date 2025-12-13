// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class UnusableTunnelDetailViewController: NSViewController {

    var onButtonClicked: (() -> Void)?

    let messageLabel: NSTextField = {
        let text = tr("macUnusableTunnelMessage")
        let boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        let boldText = NSAttributedString(string: text, attributes: [.font: boldFont])
        let label = NSTextField(labelWithAttributedString: boldText)
        return label
    }()

    let infoLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString: tr("macUnusableTunnelInfo"))
        return label
    }()

    let button: NSButton = {
        let button = NSButton()
        button.title = tr("macUnusableTunnelButtonTitleDeleteTunnel")
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        return button
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {

        button.target = self
        button.action = #selector(buttonClicked)

        let margin: CGFloat = 20
        let internalSpacing: CGFloat = 20
        let buttonSpacing: CGFloat = 30
        let stackView = NSStackView(views: [messageLabel, infoLabel, button])
        stackView.orientation = .vertical
        stackView.edgeInsets = NSEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
        stackView.spacing = internalSpacing
        stackView.setCustomSpacing(buttonSpacing, after: infoLabel)

        let view = NSView()
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.widthAnchor.constraint(equalToConstant: 360),
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 420),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])

        self.view = view
    }

    @objc func buttonClicked() {
        onButtonClicked?()
    }
}
