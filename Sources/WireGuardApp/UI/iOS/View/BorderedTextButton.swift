// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class BorderedTextButton: UIView {
    let button: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        return button
    }()

    override var intrinsicContentSize: CGSize {
        let buttonSize = button.intrinsicContentSize
        return CGSize(width: buttonSize.width + 32, height: buttonSize.height + 16)
    }

    var title: String {
        get { return button.title(for: .normal) ?? "" }
        set(value) { button.setTitle(value, for: .normal) }
    }

    var onTapped: (() -> Void)?

    init() {
        super.init(frame: CGRect.zero)

        layer.borderWidth = 1
        layer.cornerRadius = 5
        layer.borderColor = button.tintColor.cgColor

        addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func buttonTapped() {
        onTapped?()
    }

}
