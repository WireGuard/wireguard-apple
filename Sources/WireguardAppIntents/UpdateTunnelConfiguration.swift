// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct UpdateTunnelConfiguration: AppIntent {

    static var title = LocalizedStringResource("updateTunnelConfigurationIntentName", table: "AppIntents")
    static var description = IntentDescription(
        LocalizedStringResource("updateTunnelConfigurationDescription", table: "AppIntents")
    )

    @Parameter(
        title: LocalizedStringResource("updateTunnelConfigurationIntentTunnelParameterTitle", table: "AppIntents"),
        optionsProvider: TunnelsOptionsProvider()
    )
    var tunnelName: String

    @Parameter(
        title: LocalizedStringResource("updateTunnelConfigurationIntentPeersParameterTitle", table: "AppIntents"),
        optionsProvider: AppIntentsPeerOptionsProvider()
    )
    var peers: [AppIntentsPeer]?

    @Parameter(
        title: LocalizedStringResource("updateTunnelConfigurationIntentMergeParameterTitle", table: "AppIntents"),
        default: true
    )
    var mergeConfiguration: Bool

    @Dependency
    var tunnelsManager: TunnelsManager

    func perform() async throws -> some IntentResult {
        let peers = peers ?? []

        guard let tunnelContainer = tunnelsManager.tunnel(named: tunnelName) else {
            throw AppIntentConfigurationUpdateError.wrongTunnel(name: tunnelName)
        }

        guard let tunnelConfiguration = tunnelContainer.tunnelConfiguration else {
            throw AppIntentConfigurationUpdateError.missingConfiguration
        }

        let newConfiguration = try buildNewConfiguration(from: tunnelConfiguration, peersUpdates: peers, mergeChanges: mergeConfiguration)

        do {
            try await tunnelsManager.modify(tunnel: tunnelContainer, tunnelConfiguration: newConfiguration, onDemandOption: tunnelContainer.onDemandOption)
        } catch {
            wg_log(.error, message: error.localizedDescription)
            throw error
        }

        wg_log(.debug, message: "Updated configuration of tunnel \(tunnelName)")

        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("updateTunnelConfigurationIntentSummary \(\.$tunnelName)", table: "AppIntents") {
            \.$peers
            \.$mergeConfiguration
        }
    }

    private func buildNewConfiguration(from oldConfiguration: TunnelConfiguration, peersUpdates: [AppIntentsPeer], mergeChanges: Bool) throws -> TunnelConfiguration {
        var peers = oldConfiguration.peers

        for peerUpdate in peersUpdates {
            let peerIndex: Array<PeerConfiguration>.Index
            if let foundIndex = peers.firstIndex(where: { $0.publicKey.base64Key == peerUpdate.publicKey }) {
                peerIndex = foundIndex
                if mergeChanges == false {
                    peers[peerIndex] = PeerConfiguration(publicKey: peers[peerIndex].publicKey)
                }
            } else {
                wg_log(.debug, message: "Failed to find peer \(peerUpdate.publicKey) in tunnel with name \(tunnelName). Adding it.")

                guard let pubKeyEncoded = PublicKey(base64Key: peerUpdate.publicKey) else {
                    throw AppIntentConfigurationUpdateError.malformedPublicKey(key: peerUpdate.publicKey)
                }
                let newPeerConfig = PeerConfiguration(publicKey: pubKeyEncoded)
                peerIndex = peers.endIndex
                peers.append(newPeerConfig)
            }

            if let endpointString = peerUpdate.endpoint {
                if let newEntpoint = Endpoint(from: endpointString) {
                    peers[peerIndex].endpoint = newEntpoint
                } else {
                    wg_log(.debug, message: "Failed to convert \(endpointString) to Endpoint")
                }
            }
        }

        let newConfiguration = TunnelConfiguration(name: oldConfiguration.name, interface: oldConfiguration.interface, peers: peers)
        return newConfiguration
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct AppIntentsPeerOptionsProvider: DynamicOptionsProvider {

    func results() async throws -> ItemCollection<AppIntentsPeer> {
        // The error thrown here is not displayed correctly to the user. A Feedback
        // has been opened (FB12098463).
        throw AppIntentConfigurationUpdateError.peerOptionsUnavailable
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum AppIntentConfigurationUpdateError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case wrongTunnel(name: String)
    case missingConfiguration
    case peerOptionsUnavailable
    case malformedPublicKey(key: String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .wrongTunnel(let name):
            return LocalizedStringResource("wireguardAppIntentsWrongTunnelError \(name)", table: "AppIntents")
        case .missingConfiguration:
            return LocalizedStringResource("wireguardAppIntentsMissingConfigurationError", table: "AppIntents")
        case .peerOptionsUnavailable:
            return LocalizedStringResource("updateTunnelConfigurationIntentPeerOptionsUnavailableError", table: "AppIntents")
        case .malformedPublicKey(let malformedKey):
            return LocalizedStringResource("updateTunnelConfigurationIntentMalformedPublicKeyError \(malformedKey)", table: "AppIntents")
        }
    }
}
