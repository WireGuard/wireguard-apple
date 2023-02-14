// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class ButtonCell: UITableViewCell {
    var buttonText: String {
        get { return button.title(for: .normal) ?? "" }
        set(value) { button.setTitle(value, for: .normal) }
    }
    var hasDestructiveAction: Bool {
        get { return button.tintColor == .systemRed }
        set(value) { button.tintColor = value ? .systemRed : buttonStandardTintColor }
    }
    var onTapped: (() -> Void)?

    let button: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        return button
    }()

    var buttonStandardTintColor: UIColor

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        buttonStandardTintColor = button.tintColor
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            button.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])

        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    @objc func buttonTapped() {
        onTapped?()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        buttonText = ""
        onTapped = nil
        hasDestructiveAction = false
    }
}
