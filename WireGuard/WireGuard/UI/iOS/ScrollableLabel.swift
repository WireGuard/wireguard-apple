// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

class ScrollableLabel: UIScrollView {
    var text: String {
        get { return label.text ?? "" }
        set(value) { label.text = value }
    }
    var textColor: UIColor {
        get { return label.textColor }
        set(value) { label.textColor = value }
    }

    private let label: UILabel

    init() {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        self.label = label

        super.init(frame: CGRect.zero)

        self.isDirectionalLockEnabled = true
        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leftAnchor.constraint(equalTo: self.contentLayoutGuide.leftAnchor),
            label.topAnchor.constraint(equalTo: self.contentLayoutGuide.topAnchor),
            label.bottomAnchor.constraint(equalTo: self.contentLayoutGuide.bottomAnchor),
            label.rightAnchor.constraint(equalTo: self.contentLayoutGuide.rightAnchor),
            label.heightAnchor.constraint(equalTo: self.heightAnchor),
            ])
        // If label has less content, it should expand to fit the scrollView,
        // so that right-alignment works in the label.
        let expandToFitValueLabelConstraint = NSLayoutConstraint(item: label, attribute: .width, relatedBy: .equal,
                                                                 toItem: self, attribute: .width, multiplier: 1, constant: 0)
        expandToFitValueLabelConstraint.priority = .defaultLow + 1
        expandToFitValueLabelConstraint.isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
