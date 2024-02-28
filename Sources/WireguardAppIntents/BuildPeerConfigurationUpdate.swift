// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct BuildPeerConfigurationUpdate: AppIntent {

    static var title = LocalizedStringResource("buildPeerConfigurationUpdateIntentName", table: "AppIntents")
    static var description = IntentDescription(
        LocalizedStringResource("buildPeerConfigurationUpdateIntentDescription", table: "AppIntents")
    )

    @Parameter(
        title: LocalizedStringResource("buildPeerConfigurationUpdateIntentPublicKeyParameterTitle", table: "AppIntents")
    )
    var publicKey: String

    @Parameter(
        title: LocalizedStringResource("buildPeerConfigurationUpdateIntentEndpointParameterTitle", table: "AppIntents")
    )
    var endpoint: String

    func perform() async throws -> some IntentResult & ReturnsValue<AppIntentsPeer> {
        let peerConfigurationUpdate = AppIntentsPeer()
        peerConfigurationUpdate.publicKey = publicKey
        peerConfigurationUpdate.endpoint = endpoint

        return .result(value: peerConfigurationUpdate)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("buildPeerConfigurationUpdateIntentSummary \(\.$publicKey)", table: "AppIntents") {
            \.$endpoint
        }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct AppIntentsPeer: TransientAppEntity {
    
    static let kEndpointConfigUpdateDictionaryKey = "Endpoint"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("peerConfigurationUpdateEntityName", table: "AppIntents")
    )

    @Property(
        title: LocalizedStringResource("peerConfigurationUpdateEntityPropertyPublicKeyTitle", table: "AppIntents")
    )
    var publicKey: String

    @Property(
        title: LocalizedStringResource("peerConfigurationUpdateEntityPropertyEndpointTitle", table: "AppIntents")
    )
    var endpoint: String?

    var displayRepresentation: DisplayRepresentation {
        var dictionary: [String: [String: String]] = [:]
        dictionary[publicKey] = [:]

        if let endpoint {
            dictionary[publicKey]?.updateValue(endpoint, forKey: Self.kEndpointConfigUpdateDictionaryKey)
        }

        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: dictionary)
        } catch {
            return DisplayRepresentation(stringLiteral: error.localizedDescription)
        }

        let jsonString = String(data: jsonData, encoding: .utf8)!

        return DisplayRepresentation(stringLiteral: jsonString)
    }
}
