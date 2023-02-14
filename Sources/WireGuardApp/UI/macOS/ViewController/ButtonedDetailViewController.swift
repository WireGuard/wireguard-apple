// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class ButtonedDetailViewController: NSViewController {

    var onButtonClicked: (() -> Void)?

    let button: NSButton = {
        let button = NSButton()
        button.title = ""
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
        let view = NSView()

        button.target = self
        button.action = #selector(buttonClicked)

        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])

        self.view = view
    }

    func setButtonTitle(_ title: String) {
        button.title = title
    }

    @objc func buttonClicked() {
        onButtonClicked?()
    }
}
