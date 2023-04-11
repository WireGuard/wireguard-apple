// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Foundation
import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct UpdateConfiguration: AppIntent {

    static var title = LocalizedStringResource("updateConfigurationIntentName", table: "AppIntents")
    static var description = IntentDescription(
        LocalizedStringResource("updateConfigurationIntentDescription", table: "AppIntents")
    )

    @Parameter(
        title: LocalizedStringResource("updateConfigurationIntentTunnelParameterTitle", table: "AppIntents"),
        optionsProvider: TunnelsOptionsProvider()
    )
    var tunnelName: String

    @Parameter(
        title: LocalizedStringResource("updateConfigurationIntentConfigurationParameterTitle", table: "AppIntents"),
        default: #"{"Peer Public Key": {"Endpoint":"1.2.3.4:5678"} }"#,
        // Multiline not working in iOS 16.4 (FB12099849)
        inputOptions: .init(capitalizationType: .none, multiline: true, autocorrect: false,
                            smartQuotes: false, smartDashes: false)
    )
    var configurationsString: String

    @Dependency
    var tunnelsManager: TunnelsManager

    func perform() async throws -> some IntentResult {
        guard let tunnelContainer = tunnelsManager.tunnel(named: tunnelName) else {
            throw UpdateConfigurationIntentError.wrongTunnel(name: tunnelName)
        }

        guard let tunnelConfiguration = tunnelContainer.tunnelConfiguration else {
            throw UpdateConfigurationIntentError.missingConfiguration
        }

        let confugurationsUpdates = try extractConfigurationDictionary(from: configurationsString)

        let newConfiguration = try buildNewConfiguration(from: tunnelConfiguration, configurationUpdates: confugurationsUpdates)

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
        Summary("updateConfigurationIntentSummary \(\.$tunnelName)", table: "AppIntents") {
            \.$configurationsString
        }
    }

    private func extractConfigurationDictionary(from configurationString: String) throws -> [String: [String: String]] {
        let configurationsData = Data(configurationsString.utf8)

        var configurations: [String: [String: String]]
        do {
            let decodedJson = try JSONSerialization.jsonObject(with: configurationsData, options: [])
            // Make sure this JSON is in the format we expect
            if let configDictionary = decodedJson as? [String: [String: String]] {
                configurations = configDictionary
            } else {
                throw UpdateConfigurationIntentError.invalidConfiguration
            }
        } catch {
            wg_log(.error, message: "Failed to decode configuration data in JSON format for \(tunnelName). \(error.localizedDescription)")
            
            throw UpdateConfigurationIntentError.jsonDecodingFailure
        }

        return configurations
    }

    private func buildNewConfiguration(from oldConfiguration: TunnelConfiguration, configurationUpdates: [String: [String: String]]) throws -> TunnelConfiguration {
        var peers = oldConfiguration.peers

        for (peerPubKey, valuesToUpdate) in configurationUpdates {
            if let peerIndex = peers.firstIndex(where: { $0.publicKey.base64Key == peerPubKey }) {
                if let endpointString = valuesToUpdate[kEndpointConfigurationUpdateDictionaryKey] {
                    if let newEntpoint = Endpoint(from: endpointString) {
                        peers[peerIndex].endpoint = newEntpoint
                    } else {
                        wg_log(.debug, message: "Failed to convert \(endpointString) to Endpoint")
                    }
                }
            } else {
                wg_log(.debug, message: "Failed to find peer \(peerPubKey) in tunnel with name \(tunnelName). Adding it.")

                guard let pubKeyEncoded = PublicKey(base64Key: peerPubKey) else {
                    throw UpdateConfigurationIntentError.malformedPublicKey(key: peerPubKey)
                }
                let newPeerConfig = PeerConfiguration(publicKey: pubKeyEncoded)
                peers.append(newPeerConfig)
            }
        }

        let newConfiguration = TunnelConfiguration(name: oldConfiguration.name, interface: oldConfiguration.interface, peers: peers)
        return newConfiguration
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum UpdateConfigurationIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case wrongTunnel(name: String)
    case missingConfiguration
    case invalidConfiguration
    case jsonDecodingFailure
    case malformedPublicKey(key: String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .wrongTunnel(let name):
            return LocalizedStringResource("wireguardAppIntentsWrongTunnelError \(name)", table: "AppIntents")
        case .missingConfiguration:
            return LocalizedStringResource("wireguardAppIntentsMissingConfigurationError", table: "AppIntents")
        case .invalidConfiguration:
            return LocalizedStringResource("updateConfigurationIntentInvalidConfigurationError", table: "AppIntents")
        case .jsonDecodingFailure:
            return LocalizedStringResource("updateConfigurationIntentJsonDecodingError", table: "AppIntents")
        case .malformedPublicKey(let malformedKey):
            return LocalizedStringResource("updateConfigurationIntentMalformedPublicKeyError \(malformedKey)", table: "AppIntents")
        }
    }
}
