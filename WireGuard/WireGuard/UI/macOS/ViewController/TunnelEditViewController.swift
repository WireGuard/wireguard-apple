// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Cocoa

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

    let textView: NSTextView = {
        let textView = ConfTextView()
        let minWidth: CGFloat = 120
        let minHeight: CGFloat = 60
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width, .height]
        textView.isHorizontallyResizable = true
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

    let scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
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

    let tunnelsManager: TunnelsManager
    let tunnel: TunnelContainer?

    init(tunnelsManager: TunnelsManager, tunnel: TunnelContainer?) {
        self.tunnelsManager = tunnelsManager
        self.tunnel = tunnel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        if let tunnel = tunnel, let tunnelConfiguration = tunnel.tunnelConfiguration {
            nameRow.value = tunnel.name
            publicKeyRow.value = tunnelConfiguration.interface.publicKey.base64EncodedString()
            textView.string = tunnelConfiguration.asWgQuickConfig()
        }

        scrollView.documentView = textView

        saveButton.target = self
        saveButton.action = #selector(saveButtonClicked)

        discardButton.target = self
        discardButton.action = #selector(discardButtonClicked)

        let margin: CGFloat = 20
        let internalSpacing: CGFloat = 10

        let editorStackView = NSStackView(views: [nameRow, publicKeyRow, scrollView])
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
        containerView.frame = NSRect(x: 0, y: 0, width: 480, height: 320)

        self.view = containerView
    }

    @objc func saveButtonClicked() {
        let name = nameRow.value
        guard !name.isEmpty else {
            ErrorPresenter.showErrorAlert(title: tr("macAlertNameIsEmpty"), message: "", from: self)
            return
        }
        if let tunnel = tunnel {
            // We're modifying an existing tunnel
            if name != tunnel.name && tunnelsManager.tunnel(named: name) != nil {
                ErrorPresenter.showErrorAlert(title: tr(format: "macAlertDuplicateName (%@)", name), message: "", from: self)
                return
            }
            do {
                let tunnelConfiguration = try TunnelConfiguration(fromWgQuickConfig: textView.string, called: nameRow.value, ignoreUnrecognizedKeys: false)
                let onDemandSetting = ActivateOnDemandSetting.defaultSetting
                tunnelsManager.modify(tunnel: tunnel, tunnelConfiguration: tunnelConfiguration, activateOnDemandSetting: onDemandSetting) { [weak self] error in
                    if let error = error {
                        ErrorPresenter.showErrorAlert(error: error, from: self)
                        return
                    }
                    self?.dismiss(self)
                }
            } catch let error as WireGuardAppError {
                ErrorPresenter.showErrorAlert(error: error, from: self)
            } catch {
                fatalError()
            }
        }
    }

    @objc func discardButtonClicked() {
        dismiss(self)
    }
}
