// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class TunnelListCell: UITableViewCell {
    var tunnel: TunnelContainer? {
        didSet {
            // Bind to the tunnel's name
            nameLabel.text = tunnel?.name ?? ""
            nameObservationToken = tunnel?.observe(\.name) { [weak self] tunnel, _ in
                self?.nameLabel.text = tunnel.name
            }
            // Bind to the tunnel's status
            update(from: tunnel, animated: false)
            statusObservationToken = tunnel?.observe(\.status) { [weak self] tunnel, _ in
                self?.update(from: tunnel, animated: true)
            }
            // Bind to tunnel's on-demand settings
            isOnDemandEnabledObservationToken = tunnel?.observe(\.isActivateOnDemandEnabled) { [weak self] tunnel, _ in
                self?.update(from: tunnel, animated: true)
            }
            hasOnDemandRulesObservationToken = tunnel?.observe(\.hasOnDemandRules) { [weak self] tunnel, _ in
                self?.update(from: tunnel, animated: true)
            }
        }
    }
    var onSwitchToggled: ((Bool) -> Void)?

    let nameLabel: UILabel = {
        let nameLabel = UILabel()
        nameLabel.font = UIFont.preferredFont(forTextStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 0
        return nameLabel
    }()

    let onDemandLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.preferredFont(forTextStyle: .caption2)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        label.textColor = .secondaryLabel
        return label
    }()

    let busyIndicator: UIActivityIndicatorView = {
        let busyIndicator: UIActivityIndicatorView
        busyIndicator = UIActivityIndicatorView(style: .medium)
        busyIndicator.hidesWhenStopped = true
        return busyIndicator
    }()

    let statusSwitch = UISwitch()

    private var nameObservationToken: NSKeyValueObservation?
    private var statusObservationToken: NSKeyValueObservation?
    private var isOnDemandEnabledObservationToken: NSKeyValueObservation?
    private var hasOnDemandRulesObservationToken: NSKeyValueObservation?

    private var subTitleLabelBottomConstraint: NSLayoutConstraint?
    private var nameLabelBottomConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        accessoryType = .disclosureIndicator

        for subview in [statusSwitch, busyIndicator, onDemandLabel, nameLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(subview)
        }

        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        onDemandLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        let nameLabelBottomConstraint =
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: nameLabel.bottomAnchor, multiplier: 1)
        nameLabelBottomConstraint.priority = .defaultLow

        NSLayoutConstraint.activate([
            statusSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusSwitch.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            statusSwitch.leadingAnchor.constraint(equalToSystemSpacingAfter: busyIndicator.trailingAnchor, multiplier: 1),
            statusSwitch.leadingAnchor.constraint(equalToSystemSpacingAfter: onDemandLabel.trailingAnchor, multiplier: 1),

            nameLabel.topAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.topAnchor, multiplier: 1),
            nameLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: contentView.layoutMarginsGuide.leadingAnchor, multiplier: 1),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusSwitch.leadingAnchor),
            nameLabelBottomConstraint,

            onDemandLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            onDemandLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: nameLabel.trailingAnchor, multiplier: 1),

            busyIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            busyIndicator.leadingAnchor.constraint(greaterThanOrEqualToSystemSpacingAfter: nameLabel.trailingAnchor, multiplier: 1)
        ])

        statusSwitch.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        reset(animated: false)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        statusSwitch.isEnabled = !editing
    }

    @objc private func switchToggled() {
        onSwitchToggled?(statusSwitch.isOn)
    }

    private func update(from tunnel: TunnelContainer?, animated: Bool) {
        guard let tunnel = tunnel else {
            reset(animated: animated)
            return
        }
        let status = tunnel.status
        let isOnDemandEngaged = tunnel.isActivateOnDemandEnabled

        let shouldSwitchBeOn = ((status != .deactivating && status != .inactive) || isOnDemandEngaged)
        statusSwitch.setOn(shouldSwitchBeOn, animated: true)

        if isOnDemandEngaged && !(status == .activating || status == .active) {
            statusSwitch.onTintColor = UIColor.systemYellow
        } else {
            statusSwitch.onTintColor = UIColor.systemGreen
        }

        statusSwitch.isUserInteractionEnabled = (status == .inactive || status == .active)

        if tunnel.hasOnDemandRules {
            onDemandLabel.text = isOnDemandEngaged ? tr("tunnelListCaptionOnDemand") : ""
            busyIndicator.stopAnimating()
            statusSwitch.isUserInteractionEnabled = true
        } else {
            onDemandLabel.text = ""
            if status == .inactive || status == .active {
                busyIndicator.stopAnimating()
            } else {
                busyIndicator.startAnimating()
            }
            statusSwitch.isUserInteractionEnabled = (status == .inactive || status == .active)
        }

    }

    private func reset(animated: Bool) {
        statusSwitch.thumbTintColor = nil
        statusSwitch.setOn(false, animated: animated)
        statusSwitch.isUserInteractionEnabled = false
        busyIndicator.stopAnimating()
    }
}
