// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class ChevronCell: UITableViewCell {
    var message: String {
        get { return textLabel?.text ?? "" }
        set(value) { textLabel?.text = value }
    }

    var detailMessage: String {
        get { return detailTextLabel?.text ?? "" }
        set(value) { detailTextLabel?.text = value }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        message = ""
    }
}
