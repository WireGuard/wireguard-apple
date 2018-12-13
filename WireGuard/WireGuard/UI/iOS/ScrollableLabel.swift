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

    let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        return label
    }()

    init() {
        super.init(frame: CGRect.zero)

        isDirectionalLockEnabled = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leftAnchor.constraint(equalTo: contentLayoutGuide.leftAnchor),
            label.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            label.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            label.rightAnchor.constraint(equalTo: contentLayoutGuide.rightAnchor),
            label.heightAnchor.constraint(equalTo: heightAnchor)
        ])

        let expandToFitValueLabelConstraint = NSLayoutConstraint(item: label, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1, constant: 0)
        expandToFitValueLabelConstraint.priority = .defaultLow + 1
        expandToFitValueLabelConstraint.isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
