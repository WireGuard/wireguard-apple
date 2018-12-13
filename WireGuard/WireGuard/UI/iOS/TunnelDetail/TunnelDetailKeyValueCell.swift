// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

class TunnelDetailKeyValueCell: CopyableLabelTableViewCell {
    var key: String {
        get { return keyLabel.text ?? "" }
        set(value) { keyLabel.text = value }
    }
    var value: String {
        get { return valueLabel.text }
        set(value) { valueLabel.text = value }
    }
    
    override var textToCopy: String? {
        return self.valueLabel.text
    }
    
    let keyLabel: UILabel = {
        let keyLabel = UILabel()
        keyLabel.font = UIFont.preferredFont(forTextStyle: .body)
        keyLabel.adjustsFontForContentSizeCategory = true
        keyLabel.textColor = .black
        return keyLabel
    }()
    
    let valueLabel: ScrollableLabel = {
        let valueLabel = ScrollableLabel()
        valueLabel.label.font = UIFont.preferredFont(forTextStyle: .body)
        valueLabel.label.adjustsFontForContentSizeCategory = true
        valueLabel.textColor = .gray
        return valueLabel
    }()
    
    var isStackedHorizontally = false
    var isStackedVertically = false
    var contentSizeBasedConstraints = [NSLayoutConstraint]()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(keyLabel)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        keyLabel.textAlignment = .left
        NSLayoutConstraint.activate([
            keyLabel.leftAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leftAnchor),
            keyLabel.topAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.topAnchor, multiplier: 0.5)
            ])
        
        contentView.addSubview(valueLabel)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            valueLabel.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor),
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: valueLabel.bottomAnchor, multiplier: 0.5)
            ])
        
        keyLabel.setContentCompressionResistancePriority(.defaultHigh + 1, for: .horizontal)
        keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        configureForContentSize()
    }
    
    func configureForContentSize() {
        var constraints = [NSLayoutConstraint]()
        if self.traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            // Stack vertically
            if !isStackedVertically {
                constraints = [
                    valueLabel.topAnchor.constraint(equalToSystemSpacingBelow: keyLabel.bottomAnchor, multiplier: 0.5),
                    valueLabel.leftAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leftAnchor),
                    keyLabel.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor)
                ]
                isStackedVertically = true
                isStackedHorizontally = false
            }
        } else {
            // Stack horizontally
            if !isStackedHorizontally {
                constraints = [
                    contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: keyLabel.bottomAnchor, multiplier: 0.5),
                    valueLabel.leftAnchor.constraint(equalToSystemSpacingAfter: keyLabel.rightAnchor, multiplier: 1),
                    valueLabel.topAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.topAnchor, multiplier: 0.5)
                ]
                isStackedHorizontally = true
                isStackedVertically = false
            }
        }
        if !constraints.isEmpty {
            NSLayoutConstraint.deactivate(self.contentSizeBasedConstraints)
            NSLayoutConstraint.activate(constraints)
            self.contentSizeBasedConstraints = constraints
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        key = ""
        value = ""
        configureForContentSize()
    }
}
