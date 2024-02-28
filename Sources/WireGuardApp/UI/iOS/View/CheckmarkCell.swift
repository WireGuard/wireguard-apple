// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class CheckmarkCell: UITableViewCell {
    var message: String {
        get { return textLabel?.text ?? "" }
        set(value) { textLabel!.text = value }
    }
    var isChecked: Bool {
        didSet {
            accessoryType = isChecked ? .checkmark : .none
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        isChecked = false
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        message = ""
        isChecked = false
    }
}
