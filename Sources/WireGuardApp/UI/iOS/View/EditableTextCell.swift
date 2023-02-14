// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class EditableTextCell: UITableViewCell {
    var message: String {
        get { return valueTextField.text ?? "" }
        set(value) { valueTextField.text = value }
    }

    var placeholder: String? {
        get { return valueTextField.placeholder }
        set(value) { valueTextField.placeholder = value }
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
        // Reduce the bottom margin by 0.5pt to maintain the default cell height (44pt)
        let bottomAnchorConstraint = contentView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: valueTextField.bottomAnchor, constant: -0.5)
        bottomAnchorConstraint.priority = .defaultLow
        NSLayoutConstraint.activate([
            valueTextField.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            contentView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: valueTextField.trailingAnchor),
            contentView.layoutMarginsGuide.topAnchor.constraint(equalTo: valueTextField.topAnchor),
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
        placeholder = nil
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
