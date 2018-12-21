// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import NetworkExtension

class ErrorNotifier {

    let activationAttemptId: String?
    weak var tunnelProvider: NEPacketTunnelProvider?

    var tunnelName: String?
    var isActivateOnDemandEnabled = false

    init(activationAttemptId: String?, tunnelProvider: NEPacketTunnelProvider) {
        self.activationAttemptId = activationAttemptId
        self.tunnelProvider = tunnelProvider
        ErrorNotifier.removeLastErrorFile()
    }

    func errorMessage(for error: PacketTunnelProviderError) -> (String, String)? {
        switch error {
        case .savedProtocolConfigurationIsInvalid:
            return ("Activation failure", "Could not retrieve tunnel information from the saved configuration.")
        case .dnsResolutionFailure:
            return ("DNS resolution failure", "One or more endpoint domains could not be resolved.")
        case .couldNotStartWireGuard:
            return ("Activation failure", "WireGuard backend could not be started.")
        case .coultNotSetNetworkSettings:
            return ("Activation failure", "Error applying network settings on the tunnel.")
        }
    }

    func notify(_ error: PacketTunnelProviderError) {
        guard let (title, message) = errorMessage(for: error) else { return }
        if let activationAttemptId = activationAttemptId, let lastErrorFilePath = FileManager.networkExtensionLastErrorFileURL?.path {
            // The tunnel was started from the app
            let onDemandMessage = isActivateOnDemandEnabled ? " This tunnel has Activate On Demand enabled, so this tunnel might be activated automatically. You may turn off Activate On Demand in the WireGuard app by navigating to: '\(tunnelName ?? "tunnel")' > Edit." : ""
            let errorMessageData = "\(activationAttemptId)\n\(title)\n\(message)\(onDemandMessage)".data(using: .utf8)
            FileManager.default.createFile(atPath: lastErrorFilePath, contents: errorMessageData, attributes: nil)
        } else {
            // The tunnel was probably started from iOS Settings app or activated on-demand
            if let tunnelProvider = self.tunnelProvider {
                // displayMessage() is deprecated, but there's no better alternative if invoked from iOS Settings
                if !isActivateOnDemandEnabled { // If using activate-on-demand, don't use displayMessage
                    tunnelProvider.displayMessage("\(title): \(message)") { _ in }
                }
            }
        }
    }

    static func removeLastErrorFile() {
        if let lastErrorFileURL = FileManager.networkExtensionLastErrorFileURL {
            _ = FileManager.deleteFile(at: lastErrorFileURL)
        }
    }
}
