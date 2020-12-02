// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import UIKit

class EditableTextCell: UITableViewCell {
    var message: String {
        get { return valueTextField.text ?? "" }
        set(value) { valueTextField.text = value }
    }

    let valueTextField: UITextField = {
        let valueTextField = UITextField()
        valueTextField.textAlignment = .left
        valueTextField.isEnabled = true
        valueTextField.font = UIFont.preferredFont(forTextStyle: .body)
        valueTextField.adjustsFontForContentSizeCategory = true
        valueTextField.autocapitalizationType = .none
        valueTextField.autocorrectionType = .no
        valueTextField.spellCheckingType = .no
        return valueTextField
    }()

    var onValueBeingEdited: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        valueTextField.delegate = self
        contentView.addSubview(valueTextField)
        valueTextField.translatesAutoresizingMaskIntoConstraints = false
        let bottomAnchorConstraint = contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: valueTextField.bottomAnchor, multiplier: 1)
        bottomAnchorConstraint.priority = .defaultLow
        NSLayoutConstraint.activate([
            valueTextField.leadingAnchor.constraint(equalToSystemSpacingAfter: contentView.layoutMarginsGuide.leadingAnchor, multiplier: 1),
            contentView.layoutMarginsGuide.trailingAnchor.constraint(equalToSystemSpacingAfter: valueTextField.trailingAnchor, multiplier: 1),
            valueTextField.topAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.topAnchor, multiplier: 1),
            bottomAnchorConstraint
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func beginEditing() {
        valueTextField.becomeFirstResponder()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        message = ""
    }
}

extension EditableTextCell: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let onValueBeingEdited = onValueBeingEdited {
            let modifiedText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
            onValueBeingEdited(modifiedText)
        }
        return true
    }
}
