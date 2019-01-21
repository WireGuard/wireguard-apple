// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Cocoa

protocol TunnelEditViewControllerDelegate: class {
    func tunnelSaved(tunnel: TunnelContainer)
    func tunnelEditingCancelled()
}

class TunnelEditViewController: NSViewController {

    let nameRow: EditableKeyValueRow = {
        let nameRow = EditableKeyValueRow()
        nameRow.key = tr(format: "macFieldKey (%@)", TunnelViewModel.InterfaceField.name.localizedUIString)
        return nameRow
    }()

    let publicKeyRow: KeyValueRow = {
        let publicKeyRow = KeyValueRow()
        publicKeyRow.key = tr(format: "macFieldKey (%@)", TunnelViewModel.InterfaceField.publicKey.localizedUIString)
        return publicKeyRow
    }()

    let textView: ConfTextView = {
        let textView = ConfTextView()
        let minWidth: CGFloat = 120
        let minHeight: CGFloat = 0
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width] // Width should be based on superview width
        textView.isHorizontallyResizable = false // Width shouldn't be based on content
        textView.isVerticallyResizable = true // Height should be based on content
        if let textContainer = textView.textContainer {
            textContainer.size = NSSize(width: minWidth, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
        }
        NSLayoutConstraint.activate([
            textView.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight)
        ])
        return textView
    }()

    let onDemandRow: PopupRow = {
        let popupRow = PopupRow()
        popupRow.key = tr("macFieldOnDemand")
        return popupRow
    }()

    let scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        return scrollView
    }()

    let discardButton: NSButton = {
        let button = NSButton()
        button.title = tr("macEditDiscard")
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        return button
    }()

    let saveButton: NSButton = {
        let button = NSButton()
        button.title = tr("macEditSave")
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        return button
    }()

    let activateOnDemandOptions: [ActivateOnDemandOption] = [
        .none,
        .useOnDemandOverWiFiOrEthernet,
        .useOnDemandOverWiFiOnly,
        .useOnDemandOverEthernetOnly
    ]

    let tunnelsManager: TunnelsManager
    let tunnel: TunnelContainer?

    weak var delegate: TunnelEditViewControllerDelegate?

    var textViewObservationToken: AnyObject?

    init(tunnelsManager: TunnelsManager, tunnel: TunnelContainer?) {
        self.tunnelsManager = tunnelsManager
        self.tunnel = tunnel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func populateTextFields() {
        let selectedActivateOnDemandOption: ActivateOnDemandOption
        if let tunnel = tunnel {
            // Editing an existing tunnel
            let tunnelConfiguration = tunnel.tunnelConfiguration!
            nameRow.value = tunnel.name
            textView.string = tunnelConfiguration.asWgQuickConfig()
            publicKeyRow.value = tunnelConfiguration.interface.publicKey.base64EncodedString()
            textView.privateKeyString = tunnelConfiguration.interface.privateKey.base64EncodedString()
            textViewObservationToken = textView.observe(\.privateKeyString) { [weak publicKeyRow] textView, _ in
                if let privateKeyString = textView.privateKeyString,
                    let privateKey = Data(base64Encoded: privateKeyString),
                    privateKey.count == TunnelConfiguration.keyLength {
                    let publicKey = Curve25519.generatePublicKey(fromPrivateKey: privateKey)
                    publicKeyRow?.value = publicKey.base64EncodedString()
                } else {
                    publicKeyRow?.value = ""
                }
            }
            if tunnel.activateOnDemandSetting.isActivateOnDemandEnabled {
                selectedActivateOnDemandOption = tunnel.activateOnDemandSetting.activateOnDemandOption
            } else {
                selectedActivateOnDemandOption = .none
            }
        } else {
            // Creating a new tunnel
            let privateKey = Curve25519.generatePrivateKey()
            let publicKey = Curve25519.generatePublicKey(fromPrivateKey: privateKey)
            let bootstrappingText = "[Interface]\nPrivateKey = \(privateKey.base64EncodedString())\n"
            publicKeyRow.value = publicKey.base64EncodedString()
            textView.string = bootstrappingText
            selectedActivateOnDemandOption = .none
        }

        onDemandRow.valueOptions = activateOnDemandOptions.map { TunnelViewModel.activateOnDemandOptionText(for: $0) }
        onDemandRow.selectedOptionIndex = activateOnDemandOptions.firstIndex(of: selectedActivateOnDemandOption)!
    }

    override func loadView() {
        populateTextFields()

        scrollView.documentView = textView

        saveButton.target = self
        saveButton.action = #selector(handleSaveAction)

        discardButton.target = self
        discardButton.action = #selector(handleDiscardAction)

        let margin: CGFloat = 20
        let internalSpacing: CGFloat = 10

        let editorStackView = NSStackView(views: [nameRow, publicKeyRow, onDemandRow, scrollView])
        editorStackView.orientation = .vertical
        editorStackView.setHuggingPriority(.defaultHigh, for: .horizontal)
        editorStackView.spacing = internalSpacing

        let buttonRowStackView = NSStackView()
        buttonRowStackView.setViews([discardButton, saveButton], in: .trailing)
        buttonRowStackView.orientation = .horizontal
        buttonRowStackView.spacing = internalSpacing

        let containerView = NSStackView(views: [editorStackView, buttonRowStackView])
        containerView.orientation = .vertical
        containerView.edgeInsets = NSEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
        containerView.setHuggingPriority(.defaultHigh, for: .horizontal)
        containerView.spacing = internalSpacing

        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])
        containerView.frame = NSRect(x: 0, y: 0, width: 600, height: 480)

        self.view = containerView
    }

    @objc func handleSaveAction() {
        let name = nameRow.value
        guard !name.isEmpty else {
            ErrorPresenter.showErrorAlert(title: tr("macAlertNameIsEmpty"), message: "", from: self)
            return
        }
        let onDemandSetting: ActivateOnDemandSetting
        let onDemandOption = activateOnDemandOptions[onDemandRow.selectedOptionIndex]
        if onDemandOption == .none {
            onDemandSetting = ActivateOnDemandSetting.defaultSetting
        } else {
            onDemandSetting = ActivateOnDemandSetting(isActivateOnDemandEnabled: true, activateOnDemandOption: onDemandOption)
        }
        if let tunnel = tunnel {
            // We're modifying an existing tunnel
            if name != tunnel.name && tunnelsManager.tunnel(named: name) != nil {
                ErrorPresenter.showErrorAlert(title: tr(format: "macAlertDuplicateName (%@)", name), message: "", from: self)
                return
            }
            do {
                let tunnelConfiguration = try TunnelConfiguration(fromWgQuickConfig: textView.string, called: nameRow.value)
                tunnelsManager.modify(tunnel: tunnel, tunnelConfiguration: tunnelConfiguration, activateOnDemandSetting: onDemandSetting) { [weak self] error in
                    if let error = error {
                        ErrorPresenter.showErrorAlert(error: error, from: self)
                        return
                    }
                    self?.dismiss(self)
                    self?.delegate?.tunnelSaved(tunnel: tunnel)
                }
            } catch let error as WireGuardAppError {
                ErrorPresenter.showErrorAlert(error: error, from: self)
            } catch {
                fatalError()
            }
        } else {
            // We're creating a new tunnel
            if tunnelsManager.tunnel(named: name) != nil {
                ErrorPresenter.showErrorAlert(title: tr(format: "macAlertDuplicateName (%@)", name), message: "", from: self)
                return
            }
            do {
                let tunnelConfiguration = try TunnelConfiguration(fromWgQuickConfig: textView.string, called: nameRow.value)
                tunnelsManager.add(tunnelConfiguration: tunnelConfiguration, activateOnDemandSetting: onDemandSetting) { [weak self] result in
                    if let error = result.error {
                        ErrorPresenter.showErrorAlert(error: error, from: self)
                    } else {
                        let tunnel: TunnelContainer = result.value!
                        self?.dismiss(self)
                        self?.delegate?.tunnelSaved(tunnel: tunnel)
                    }
                }
            } catch let error as WireGuardAppError {
                ErrorPresenter.showErrorAlert(error: error, from: self)
            } catch {
                fatalError()
            }
        }
    }

    @objc func handleDiscardAction() {
        delegate?.tunnelEditingCancelled()
        dismiss(self)
    }
}
