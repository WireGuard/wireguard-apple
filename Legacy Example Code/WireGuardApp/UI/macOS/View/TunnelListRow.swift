// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

class TunnelListRow: NSView {
    var tunnel: TunnelContainer? {
        didSet(value) {
            // Bind to the tunnel's name
            nameLabel.stringValue = tunnel?.name ?? ""
            nameObservationToken = tunnel?.observe(\TunnelContainer.name) { [weak self] tunnel, _ in
                self?.nameLabel.stringValue = tunnel.name
            }
            // Bind to the tunnel's status
            statusImageView.image = TunnelListRow.image(for: tunnel)
            statusObservationToken = tunnel?.observe(\TunnelContainer.status) { [weak self] tunnel, _ in
                self?.statusImageView.image = TunnelListRow.image(for: tunnel)
            }
            isOnDemandEnabledObservationToken = tunnel?.observe(\TunnelContainer.isActivateOnDemandEnabled) { [weak self] tunnel, _ in
                self?.statusImageView.image = TunnelListRow.image(for: tunnel)
            }
        }
    }

    let nameLabel: NSTextField = {
        let nameLabel = NSTextField()
        nameLabel.isEditable = false
        nameLabel.isSelectable = false
        nameLabel.isBordered = false
        nameLabel.maximumNumberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        return nameLabel
    }()

    let statusImageView = NSImageView()

    private var statusObservationToken: AnyObject?
    private var nameObservationToken: AnyObject?
    private var isOnDemandEnabledObservationToken: AnyObject?

    init() {
        super.init(frame: CGRect.zero)

        addSubview(statusImageView)
        addSubview(nameLabel)
        statusImageView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.backgroundColor = .clear
        NSLayoutConstraint.activate([
            self.leadingAnchor.constraint(equalTo: statusImageView.leadingAnchor),
            statusImageView.trailingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            statusImageView.widthAnchor.constraint(equalToConstant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            statusImageView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func image(for tunnel: TunnelContainer?) -> NSImage? {
        guard let tunnel = tunnel else { return nil }
        switch tunnel.status {
        case .active, .restarting, .reasserting:
            return NSImage(named: NSImage.statusAvailableName)
        case .activating, .waiting, .deactivating:
            return NSImage(named: NSImage.statusPartiallyAvailableName)
        case .inactive:
            if tunnel.isActivateOnDemandEnabled {
                return NSImage(named: NSImage.Name.statusOnDemandEnabled)
            } else {
                return NSImage(named: NSImage.statusNoneName)
            }
        }
    }

    override func prepareForReuse() {
        nameLabel.stringValue = ""
        statusImageView.image = nil
    }
}

extension NSImage.Name {
    static let statusOnDemandEnabled = NSImage.Name("StatusCircleYellow")
}
