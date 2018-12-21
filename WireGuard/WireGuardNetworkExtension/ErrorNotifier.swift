// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import NetworkExtension

class ErrorNotifier {

    let activationAttemptId: String?
    weak var tunnelProvider: NEPacketTunnelProvider?

    var tunnelName: String?

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
        guard let (title, message) = errorMessage(for: error), let activationAttemptId = activationAttemptId, let lastErrorFilePath = FileManager.networkExtensionLastErrorFileURL?.path else { return }
        let errorMessageData = "\(activationAttemptId)\n\(title)\n\(message)".data(using: .utf8)
        FileManager.default.createFile(atPath: lastErrorFilePath, contents: errorMessageData, attributes: nil)
    }

    static func removeLastErrorFile() {
        if let lastErrorFileURL = FileManager.networkExtensionLastErrorFileURL {
            _ = FileManager.deleteFile(at: lastErrorFileURL)
        }
    }
}
