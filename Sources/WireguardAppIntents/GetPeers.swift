// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Foundation
import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct GetPeers: AppIntent {

    static var title = LocalizedStringResource("getPeersIntentName", table: "AppIntents")
    static var description = IntentDescription(
        LocalizedStringResource("getPeersIntentDescription", table: "AppIntents")
    )

    @Parameter(
        title: LocalizedStringResource("getPeersIntentTunnelParameterTitle", table: "AppIntents"),
        optionsProvider: TunnelsOptionsProvider()
    )
    var tunnelName: String

    @Dependency
    var tunnelsManager: TunnelsManager

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        guard let tunnelContainer = tunnelsManager.tunnel(named: tunnelName) else {
            throw GetPeersIntentError.wrongTunnel(name: tunnelName)
        }

        guard let tunnelConfiguration = tunnelContainer.tunnelConfiguration else {
            throw GetPeersIntentError.missingConfiguration
        }

        let publicKeys = tunnelConfiguration.peers.map { $0.publicKey.base64Key }
        return .result(value: publicKeys)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("getPeersIntentSummary \(\.$tunnelName)", table: "AppIntents")
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum GetPeersIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case wrongTunnel(name: String)
    case missingConfiguration

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .wrongTunnel(let name):
            return LocalizedStringResource("wireguardAppIntentsWrongTunnelError \(name)", table: "AppIntents")
        case .missingConfiguration:
            return LocalizedStringResource("wireguardAppIntentsMissingConfigurationError", table: "AppIntents")
        }
    }
}
