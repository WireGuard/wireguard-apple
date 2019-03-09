// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Cocoa
import CoreWLAN

class OnDemandWiFiControls: NSStackView {

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
        NSLayoutConstraint.activate([
            tokenField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])
        return tokenField
    }()

    override var intrinsicContentSize: NSSize {
        let minHeight: CGFloat = 22
        let height = max(minHeight, onDemandWiFiCheckbox.intrinsicContentSize.height, onDemandSSIDOptionsPopup.intrinsicContentSize.height, onDemandSSIDsField.intrinsicContentSize.height)
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    var onDemandViewModel: ActivateOnDemandViewModel? {
        didSet { updateSSIDControls() }
    }

    var currentSSIDs: [String]

    init() {
        currentSSIDs = getCurrentSSIDs()
        super.init(frame: CGRect.zero)
        onDemandSSIDOptionsPopup.addItems(withTitles: OnDemandWiFiControls.onDemandSSIDOptions.map { $0.localizedUIString })
        setViews([onDemandWiFiCheckbox, onDemandSSIDOptionsPopup, onDemandSSIDsField], in: .leading)
        orientation = .horizontal

        NSLayoutConstraint.activate([
            onDemandWiFiCheckbox.centerYAnchor.constraint(equalTo: centerYAnchor),
            onDemandSSIDOptionsPopup.lastBaselineAnchor.constraint(equalTo: onDemandWiFiCheckbox.lastBaselineAnchor),
            onDemandSSIDsField.lastBaselineAnchor.constraint(equalTo: onDemandWiFiCheckbox.lastBaselineAnchor)
        ])

        onDemandWiFiCheckbox.target = self
        onDemandWiFiCheckbox.action = #selector(wiFiCheckboxToggled)

        onDemandSSIDOptionsPopup.target = self
        onDemandSSIDOptionsPopup.action = #selector(ssidOptionsPopupValueChanged)

        onDemandSSIDsField.delegate = self

        updateSSIDControls()
    }

    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func saveToViewModel() {
        guard let onDemandViewModel = onDemandViewModel else { return }
        onDemandViewModel.isWiFiInterfaceEnabled = onDemandWiFiCheckbox.state == .on
        onDemandViewModel.ssidOption = OnDemandWiFiControls.onDemandSSIDOptions[onDemandSSIDOptionsPopup.indexOfSelectedItem]
        onDemandViewModel.selectedSSIDs = (onDemandSSIDsField.objectValue as? [String]) ?? []
    }

    func updateSSIDControls() {
        guard let onDemandViewModel = onDemandViewModel else { return }
        onDemandWiFiCheckbox.state = onDemandViewModel.isWiFiInterfaceEnabled ? .on : .off
        let optionIndex = OnDemandWiFiControls.onDemandSSIDOptions.firstIndex(of: onDemandViewModel.ssidOption)
        onDemandSSIDOptionsPopup.selectItem(at: optionIndex ?? 0)
        onDemandSSIDsField.objectValue = onDemandViewModel.selectedSSIDs
        onDemandSSIDOptionsPopup.isHidden = !onDemandViewModel.isWiFiInterfaceEnabled
        onDemandSSIDsField.isHidden = !onDemandViewModel.isWiFiInterfaceEnabled || onDemandViewModel.ssidOption == .anySSID
    }

    @objc func wiFiCheckboxToggled() {
        onDemandViewModel?.isWiFiInterfaceEnabled = onDemandWiFiCheckbox.state == .on
        updateSSIDControls()
    }

    @objc func ssidOptionsPopupValueChanged() {
        let selectedIndex = onDemandSSIDOptionsPopup.indexOfSelectedItem
        onDemandViewModel?.ssidOption = OnDemandWiFiControls.onDemandSSIDOptions[selectedIndex]
        onDemandViewModel?.selectedSSIDs = (onDemandSSIDsField.objectValue as? [String]) ?? []
        updateSSIDControls()
        if !onDemandSSIDsField.isHidden {
            onDemandSSIDsField.becomeFirstResponder()
        }
    }
}

extension OnDemandWiFiControls: NSTokenFieldDelegate {
    func tokenField(_ tokenField: NSTokenField, completionsForSubstring substring: String, indexOfToken tokenIndex: Int, indexOfSelectedItem selectedIndex: UnsafeMutablePointer<Int>?) -> [Any]? {
        return currentSSIDs.filter { $0.hasPrefix(substring) }
    }
}

private func getCurrentSSIDs() -> [String] {
    return CWWiFiClient.shared().interfaces()?.compactMap { $0.ssid() } ?? []
}
