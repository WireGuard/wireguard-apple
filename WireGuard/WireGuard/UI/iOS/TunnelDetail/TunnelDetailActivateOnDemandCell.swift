// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

class TunnelDetailActivateOnDemandCell: UITableViewCell {
    var tunnel: TunnelContainer? {
        didSet(value) {
            update(from: tunnel?.activateOnDemandSetting())
            onDemandStatusObservervationToken = tunnel?.observe(\.isActivateOnDemandEnabled) { [weak self] tunnel, _ in
                self?.update(from: tunnel.activateOnDemandSetting())
            }
        }
    }
    
    var onDemandStatusObservervationToken: AnyObject?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        textLabel?.text = "Activate on demand"
        textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        textLabel?.adjustsFontForContentSizeCategory = true
        detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        detailTextLabel?.adjustsFontForContentSizeCategory = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(from activateOnDemandSetting: ActivateOnDemandSetting?) {
        detailTextLabel?.text = TunnelViewModel.activateOnDemandDetailText(for: activateOnDemandSetting)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        textLabel?.text = "Activate on demand"
        detailTextLabel?.text = ""
    }
}
