// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class SwitchCell: UITableViewCell {
    var message: String {
        get { return textLabel?.text ?? "" }
        set(value) { textLabel?.text = value }
    }
    var isOn: Bool {
        get { return switchView.isOn }
        set(value) { switchView.isOn = value }
    }
    var isEnabled: Bool {
        get { return switchView.isEnabled }
        set(value) {
            switchView.isEnabled = value
            textLabel?.textColor = value ? .label : .secondaryLabel
        }
    }

    var onSwitchToggled: ((Bool) -> Void)?

    var statusObservationToken: AnyObject?
    var isOnDemandEnabledObservationToken: AnyObject?
    var hasOnDemandRulesObservationToken: AnyObject?

    let switchView = UISwitch()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)

        accessoryView = switchView
        switchView.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func switchToggled() {
        onSwitchToggled?(switchView.isOn)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onSwitchToggled = nil
        isEnabled = true
        message = ""
        isOn = false
        statusObservationToken = nil
        isOnDemandEnabledObservationToken = nil
        hasOnDemandRulesObservationToken = nil
    }
}
