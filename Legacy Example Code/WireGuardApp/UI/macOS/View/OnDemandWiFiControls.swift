// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa
import CoreWLAN

class OnDemandControlsRow: NSView {
    let keyLabel: NSTextField = {
        let keyLabel = NSTextField()
        keyLabel.stringValue = tr("macFieldOnDemand")
        keyLabel.isEditable = false
        keyLabel.isSelectable = false
        keyLabel.isBordered = false
        keyLabel.alignment = .right
        keyLabel.maximumNumberOfLines = 1
        keyLabel.lineBreakMode = .byTruncatingTail
        keyLabel.backgroundColor = .clear
        return keyLabel
    }()

    let onDemandEthernetCheckbox: NSButton = {
        let checkbox = NSButton()
        checkbox.title = tr("tunnelOnDemandEthernet")
        checkbox.setButtonType(.switch)
        checkbox.state = .off
        return checkbox
    }()

    let onDemandWiFiCheckbox: NSButton = {
        let checkbox = NSButton()
        checkbox.title = tr("tunnelOnDemandWiFi")
        checkbox.setButtonType(.switch)
        checkbox.state = .off
        return checkbox
    }()

    static let onDemandSSIDOptions: [ActivateOnDemandViewModel.OnDemandSSIDOption] = [
        .anySSID, .onlySpecificSSIDs, .exceptSpecificSSIDs
    ]

    let onDemandSSIDOptionsPopup = NSPopUpButton()

    let onDemandSSIDsField: NSTokenField = {
        let tokenField = NSTokenField()
        tokenField.tokenizingCharacterSet = CharacterSet([])
        tokenField.tokenStyle = .squared
        NSLayoutConstraint.activate([
            tokenField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])
        return tokenField
    }()

    override var intrinsicContentSize: NSSize {
        let minHeight: CGFloat = 22
        let height = max(minHeight, keyLabel.intrinsicContentSize.height,
                         onDemandEthernetCheckbox.intrinsicContentSize.height, onDemandWiFiCheckbox.intrinsicContentSize.height,
                         onDemandSSIDOptionsPopup.intrinsicContentSize.height, onDemandSSIDsField.intrinsicContentSize.height)
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    var onDemandViewModel: ActivateOnDemandViewModel? {
        didSet { updateControls() }
    }

    var currentSSIDs: [String]

    init() {
        currentSSIDs = getCurrentSSIDs()
        super.init(frame: CGRect.zero)

        onDemandSSIDOptionsPopup.addItems(withTitles: OnDemandControlsRow.onDemandSSIDOptions.map { $0.localizedUIString })

        let stackView = NSStackView()
        stackView.setViews([onDemandEthernetCheckbox, onDemandWiFiCheckbox, onDemandSSIDOptionsPopup, onDemandSSIDsField], in: .leading)
        stackView.orientation = .horizontal

        addSubview(keyLabel)
        addSubview(stackView)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            keyLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            stackView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.leadingAnchor.constraint(equalTo: keyLabel.leadingAnchor),
            stackView.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: 5),
            stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])

        keyLabel.setContentCompressionResistancePriority(.defaultHigh + 2, for: .horizontal)
        keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let widthConstraint = keyLabel.widthAnchor.constraint(equalToConstant: 150)
        widthConstraint.priority = .defaultHigh + 1
        widthConstraint.isActive = true

        NSLayoutConstraint.activate([
            onDemandEthernetCheckbox.centerYAnchor.constraint(equalTo: stackView.centerYAnchor),
            onDemandWiFiCheckbox.lastBaselineAnchor.constraint(equalTo: onDemandEthernetCheckbox.lastBaselineAnchor),
            onDemandSSIDOptionsPopup.lastBaselineAnchor.constraint(equalTo: onDemandEthernetCheckbox.lastBaselineAnchor),
            onDemandSSIDsField.lastBaselineAnchor.constraint(equalTo: onDemandEthernetCheckbox.lastBaselineAnchor)
        ])

        onDemandSSIDsField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        onDemandEthernetCheckbox.target = self
        onDemandEthernetCheckbox.action = #selector(ethernetCheckboxToggled)

        onDemandWiFiCheckbox.target = self
        onDemandWiFiCheckbox.action = #selector(wiFiCheckboxToggled)

        onDemandSSIDOptionsPopup.target = self
        onDemandSSIDOptionsPopup.action = #selector(ssidOptionsPopupValueChanged)

        onDemandSSIDsField.delegate = self

        updateControls()
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func saveToViewModel() {
        guard let onDemandViewModel = onDemandViewModel else { return }
        onDemandViewModel.isNonWiFiInterfaceEnabled = onDemandEthernetCheckbox.state == .on
        onDemandViewModel.isWiFiInterfaceEnabled = onDemandWiFiCheckbox.state == .on
        onDemandViewModel.ssidOption = OnDemandControlsRow.onDemandSSIDOptions[onDemandSSIDOptionsPopup.indexOfSelectedItem]
        onDemandViewModel.selectedSSIDs = (onDemandSSIDsField.objectValue as? [String]) ?? []
    }

    func updateControls() {
        guard let onDemandViewModel = onDemandViewModel else { return }
        onDemandEthernetCheckbox.state = onDemandViewModel.isNonWiFiInterfaceEnabled ? .on : .off
        onDemandWiFiCheckbox.state = onDemandViewModel.isWiFiInterfaceEnabled ? .on : .off
        let optionIndex = OnDemandControlsRow.onDemandSSIDOptions.firstIndex(of: onDemandViewModel.ssidOption)
        onDemandSSIDOptionsPopup.selectItem(at: optionIndex ?? 0)
        onDemandSSIDsField.objectValue = onDemandViewModel.selectedSSIDs
        onDemandSSIDOptionsPopup.isHidden = !onDemandViewModel.isWiFiInterfaceEnabled
        onDemandSSIDsField.isHidden = !onDemandViewModel.isWiFiInterfaceEnabled || onDemandViewModel.ssidOption == .anySSID
    }

    @objc func ethernetCheckboxToggled() {
        onDemandViewModel?.isNonWiFiInterfaceEnabled = onDemandEthernetCheckbox.state == .on
    }

    @objc func wiFiCheckboxToggled() {
        onDemandViewModel?.isWiFiInterfaceEnabled = onDemandWiFiCheckbox.state == .on
        updateControls()
    }

    @objc func ssidOptionsPopupValueChanged() {
        let selectedIndex = onDemandSSIDOptionsPopup.indexOfSelectedItem
        onDemandViewModel?.ssidOption = OnDemandControlsRow.onDemandSSIDOptions[selectedIndex]
        onDemandViewModel?.selectedSSIDs = (onDemandSSIDsField.objectValue as? [String]) ?? []
        updateControls()
        if !onDemandSSIDsField.isHidden {
            onDemandSSIDsField.becomeFirstResponder()
        }
    }
}

extension OnDemandControlsRow: NSTokenFieldDelegate {
    func tokenField(_ tokenField: NSTokenField, completionsForSubstring substring: String, indexOfToken tokenIndex: Int, indexOfSelectedItem selectedIndex: UnsafeMutablePointer<Int>?) -> [Any]? {
        return currentSSIDs.filter { $0.hasPrefix(substring) }
    }
}

private func getCurrentSSIDs() -> [String] {
    return CWWiFiClient.shared().interfaces()?.compactMap { $0.ssid() } ?? []
}
