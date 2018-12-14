// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

class TunnelDetailStatusCell: UITableViewCell {
    var tunnel: TunnelContainer? {
        didSet(value) {
            update(from: tunnel?.status)
            statusObservervationToken = tunnel?.observe(\.status) { [weak self] tunnel, _ in
                self?.update(from: tunnel.status)
            }
        }
    }
    var isSwitchInteractionEnabled: Bool {
        get { return statusSwitch.isUserInteractionEnabled }
        set(value) { statusSwitch.isUserInteractionEnabled = value }
    }
    var onSwitchToggled: ((Bool) -> Void)?
    private var isOnSwitchToggledHandlerEnabled = true
    
    let statusSwitch: UISwitch
    private var statusObservervationToken: AnyObject?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        statusSwitch = UISwitch()
        super.init(style: .default, reuseIdentifier: TunnelDetailKeyValueCell.reuseIdentifier)
        accessoryView = statusSwitch
        
        statusSwitch.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
    }
    
    @objc func switchToggled() {
        if isOnSwitchToggledHandlerEnabled {
            onSwitchToggled?(statusSwitch.isOn)
        }
    }
    
    private func update(from status: TunnelStatus?) {
        guard let status = status else {
            reset()
            return
        }
        let text: String
        switch status {
        case .inactive:
            text = "Inactive"
        case .activating:
            text = "Activating"
        case .active:
            text = "Active"
        case .deactivating:
            text = "Deactivating"
        case .reasserting:
            text = "Reactivating"
        case .restarting:
            text = "Restarting"
        case .waiting:
            text = "Waiting"
        }
        textLabel?.text = text
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak statusSwitch] in
            guard let statusSwitch = statusSwitch else { return }
            statusSwitch.isOn = !(status == .deactivating || status == .inactive)
            statusSwitch.isUserInteractionEnabled = (status == .inactive || status == .active)
        }
        textLabel?.textColor = (status == .active || status == .inactive) ? UIColor.black : UIColor.gray
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func reset() {
        textLabel?.text = "Invalid"
        statusSwitch.isOn = false
        textLabel?.textColor = UIColor.gray
        statusSwitch.isUserInteractionEnabled = false
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        reset()
    }
}
