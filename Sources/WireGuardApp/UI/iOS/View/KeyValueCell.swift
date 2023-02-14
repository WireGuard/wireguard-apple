// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class KeyValueCell: UITableViewCell {

    let keyLabel: UILabel = {
        let keyLabel = UILabel()
        keyLabel.font = UIFont.preferredFont(forTextStyle: .body)
        keyLabel.adjustsFontForContentSizeCategory = true
        keyLabel.textColor = .label
        keyLabel.textAlignment = .left
        return keyLabel
    }()

    let valueLabelScrollView: UIScrollView = {
        let scrollView = UIScrollView(frame: .zero)
        scrollView.isDirectionalLockEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    let valueTextField: UITextField = {
        let valueTextField = KeyValueCellTextField()
        valueTextField.textAlignment = .right
        valueTextField.isEnabled = false
        valueTextField.font = UIFont.preferredFont(forTextStyle: .body)
        valueTextField.adjustsFontForContentSizeCategory = true
        valueTextField.autocapitalizationType = .none
        valueTextField.autocorrectionType = .no
        valueTextField.spellCheckingType = .no
        valueTextField.textColor = .secondaryLabel
        return valueTextField
    }()

    var copyableGesture = true

    var key: String {
        get { return keyLabel.text ?? "" }
        set(value) { keyLabel.text = value }
    }
    var value: String {
        get { return valueTextField.text ?? "" }
        set(value) { valueTextField.text = value }
    }
    var placeholderText: String {
        get { return valueTextField.placeholder ?? "" }
        set(value) { valueTextField.placeholder = value }
    }
    var keyboardType: UIKeyboardType {
        get { return valueTextField.keyboardType }
        set(value) { valueTextField.keyboardType = value }
    }

    var isValueValid = true {
        didSet {
            if isValueValid {
                keyLabel.textColor = .label
            } else {
                keyLabel.textColor = .systemRed
            }
        }
    }

    var isStackedHorizontally = false
    var isStackedVertically = false
    var contentSizeBasedConstraints = [NSLayoutConstraint]()

    var onValueChanged: ((String, String) -> Void)?
    var onValueBeingEdited: ((String) -> Void)?

    var observationToken: AnyObject?

    private var textFieldValueOnBeginEditing: String = ""

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(keyLabel)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keyLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            keyLabel.topAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.topAnchor, multiplier: 0.5)
        ])

        valueTextField.delegate = self
        valueLabelScrollView.addSubview(valueTextField)
        valueTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueTextField.leadingAnchor.constraint(equalTo: valueLabelScrollView.contentLayoutGuide.leadingAnchor),
            valueTextField.topAnchor.constraint(equalTo: valueLabelScrollView.contentLayoutGuide.topAnchor),
            valueTextField.bottomAnchor.constraint(equalTo: valueLabelScrollView.contentLayoutGuide.bottomAnchor),
            valueTextField.trailingAnchor.constraint(equalTo: valueLabelScrollView.contentLayoutGuide.trailingAnchor),
            valueTextField.heightAnchor.constraint(equalTo: valueLabelScrollView.heightAnchor)
        ])
        let expandToFitValueLabelConstraint = NSLayoutConstraint(item: valueTextField, attribute: .width, relatedBy: .equal, toItem: valueLabelScrollView, attribute: .width, multiplier: 1, constant: 0)
        expandToFitValueLabelConstraint.priority = .defaultLow + 1
        expandToFitValueLabelConstraint.isActive = true

        contentView.addSubview(valueLabelScrollView)
        valueLabelScrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueLabelScrollView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: valueLabelScrollView.bottomAnchor, multiplier: 0.5)
        ])

        keyLabel.setContentCompressionResistancePriority(.defaultHigh + 1, for: .horizontal)
        keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        valueLabelScrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        addGestureRecognizer(gestureRecognizer)
        isUserInteractionEnabled = true

        configureForContentSize()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureForContentSize() {
        var constraints = [NSLayoutConstraint]()
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            // Stack vertically
            if !isStackedVertically {
                constraints = [
                    valueLabelScrollView.topAnchor.constraint(equalToSystemSpacingBelow: keyLabel.bottomAnchor, multiplier: 0.5),
                    valueLabelScrollView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
                    keyLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
                ]
                isStackedVertically = true
                isStackedHorizontally = false
            }
        } else {
            // Stack horizontally
            if !isStackedHorizontally {
                constraints = [
                    contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: keyLabel.bottomAnchor, multiplier: 0.5),
                    valueLabelScrollView.leadingAnchor.constraint(equalToSystemSpacingAfter: keyLabel.trailingAnchor, multiplier: 1),
                    valueLabelScrollView.topAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.topAnchor, multiplier: 0.5)
                ]
                isStackedHorizontally = true
                isStackedVertically = false
            }
        }
        if !constraints.isEmpty {
            NSLayoutConstraint.deactivate(contentSizeBasedConstraints)
            NSLayoutConstraint.activate(constraints)
            contentSizeBasedConstraints = constraints
        }
    }

    @objc func handleTapGesture(_ recognizer: UIGestureRecognizer) {
        if !copyableGesture {
            return
        }
        guard recognizer.state == .recognized else { return }

        if let recognizerView = recognizer.view,
            let recognizerSuperView = recognizerView.superview, recognizerView.becomeFirstResponder() {
            let menuController = UIMenuController.shared
            menuController.setTargetRect(detailTextLabel?.frame ?? recognizerView.frame, in: detailTextLabel?.superview ?? recognizerSuperView)
            menuController.setMenuVisible(true, animated: true)
        }
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return (action == #selector(UIResponderStandardEditActions.copy(_:)))
    }

    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = valueTextField.text
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        copyableGesture = true
        placeholderText = ""
        isValueValid = true
        keyboardType = .default
        onValueChanged = nil
        onValueBeingEdited = nil
        observationToken = nil
        key = ""
        value = ""
        configureForContentSize()
    }
}

extension KeyValueCell: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        textFieldValueOnBeginEditing = textField.text ?? ""
        isValueValid = true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        let isModified = textField.text ?? "" != textFieldValueOnBeginEditing
        guard isModified else { return }
        onValueChanged?(textFieldValueOnBeginEditing, textField.text ?? "")
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let onValueBeingEdited = onValueBeingEdited {
            let modifiedText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
            onValueBeingEdited(modifiedText)
        }
        return true
    }

}

class KeyValueCellTextField: UITextField {
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        // UIKit renders the placeholder label 0.5pt higher
        return super.placeholderRect(forBounds: bounds).integral.offsetBy(dx: 0, dy: -0.5)
    }
}
