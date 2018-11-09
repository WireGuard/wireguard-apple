// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import NetworkExtension

class ErrorNotifier {
    static func errorMessage(for error: PacketTunnelProviderError) -> (String, String)? {
        switch (error) {
        case .savedProtocolConfigurationIsInvalid:
            return ("Activation failure", "Could not retrieve tunnel information from the saved configuration")
        case .dnsResolutionFailure(_):
            return ("DNS resolution failure", "One or more endpoint domains could not be resolved")
        case .couldNotStartWireGuard:
            return ("Activation failure", "WireGuard backend could not be started")
        case .coultNotSetNetworkSettings:
            return ("Activation failure", "Error applying network settings on the tunnel")
        }
    }

    static func notify(_ error: PacketTunnelProviderError, from tunnelProvider: NEPacketTunnelProvider) {
        guard let (title, message) = ErrorNotifier.errorMessage(for: error) else { return }
        // displayMessage() is deprecated, but there's no better alternative to show the error to the user
        tunnelProvider.displayMessage("\(title): \(message)", completionHandler: { (_) in })
    }
}
