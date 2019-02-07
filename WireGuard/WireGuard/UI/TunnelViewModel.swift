// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation

//swiftlint:disable:next type_body_length
class TunnelViewModel {

    enum InterfaceField: CaseIterable {
        case name
        case privateKey
        case publicKey
        case generateKeyPair
        case addresses
        case listenPort
        case mtu
        case dns

        var localizedUIString: String {
            switch self {
            case .name: return tr("tunnelInterfaceName")
            case .privateKey: return tr("tunnelInterfacePrivateKey")
            case .publicKey: return tr("tunnelInterfacePublicKey")
            case .generateKeyPair: return tr("tunnelInterfaceGenerateKeypair")
            case .addresses: return tr("tunnelInterfaceAddresses")
            case .listenPort: return tr("tunnelInterfaceListenPort")
            case .mtu: return tr("tunnelInterfaceMTU")
            case .dns: return tr("tunnelInterfaceDNS")
            }
        }
    }

    static let interfaceFieldsWithControl: Set<InterfaceField> = [
        .generateKeyPair
    ]

    enum PeerField: CaseIterable {
        case publicKey
        case preSharedKey
        case endpoint
        case persistentKeepAlive
        case allowedIPs
        case rxBytes
        case txBytes
        case lastHandshakeTime
        case excludePrivateIPs
        case deletePeer

        var localizedUIString: String {
            switch self {
            case .publicKey: return tr("tunnelPeerPublicKey")
            case .preSharedKey: return tr("tunnelPeerPreSharedKey")
            case .endpoint: return tr("tunnelPeerEndpoint")
            case .persistentKeepAlive: return tr("tunnelPeerPersistentKeepalive")
            case .allowedIPs: return tr("tunnelPeerAllowedIPs")
            case .rxBytes: return tr("tunnelPeerRxBytes")
            case .txBytes: return tr("tunnelPeerTxBytes")
            case .lastHandshakeTime: return tr("tunnelPeerLastHandshakeTime")
            case .excludePrivateIPs: return tr("tunnelPeerExcludePrivateIPs")
            case .deletePeer: return tr("deletePeerButtonTitle")
            }
        }
    }

    static let peerFieldsWithControl: Set<PeerField> = [
        .excludePrivateIPs, .deletePeer
    ]

    static let keyLengthInBase64 = 44

    struct ChangeHandlers {
        enum FieldChange {
            case added
            case removed
            case modified
        }
        var interfaceChanged: ([InterfaceField: FieldChange]) -> Void
        var peerChangedAt: (Int, [PeerField: FieldChange]) -> Void
        var peersRemovedAt: ([Int]) -> Void
        var peersInsertedAt: ([Int]) -> Void
    }

    class InterfaceData {
        var scratchpad = [InterfaceField: String]()
        var fieldsWithError = Set<InterfaceField>()
        var validatedConfiguration: InterfaceConfiguration?
        var validatedName: String?

        subscript(field: InterfaceField) -> String {
            get {
                if scratchpad.isEmpty {
                    populateScratchpad()
                }
                return scratchpad[field] ?? ""
            }
            set(stringValue) {
                if scratchpad.isEmpty {
                    populateScratchpad()
                }
                validatedConfiguration = nil
                validatedName = nil
                if stringValue.isEmpty {
                    scratchpad.removeValue(forKey: field)
                } else {
                    scratchpad[field] = stringValue
                }
                if field == .privateKey {
                    if stringValue.count == TunnelViewModel.keyLengthInBase64, let privateKey = Data(base64Encoded: stringValue), privateKey.count == TunnelConfiguration.keyLength {
                        let publicKey = Curve25519.generatePublicKey(fromPrivateKey: privateKey)
                        scratchpad[.publicKey] = publicKey.base64EncodedString()
                    } else {
                        scratchpad.removeValue(forKey: .publicKey)
                    }
                }
            }
        }

        func populateScratchpad() {
            guard let config = validatedConfiguration else { return }
            guard let name = validatedName else { return }
            scratchpad = TunnelViewModel.InterfaceData.createScratchPad(from: config, name: name)
        }

        private static func createScratchPad(from config: InterfaceConfiguration, name: String) -> [InterfaceField: String] {
            var scratchpad = [InterfaceField: String]()
            scratchpad[.name] = name
            scratchpad[.privateKey] = config.privateKey.base64EncodedString()
            scratchpad[.publicKey] = config.publicKey.base64EncodedString()
            if !config.addresses.isEmpty {
                scratchpad[.addresses] = config.addresses.map { $0.stringRepresentation }.joined(separator: ", ")
            }
            if let listenPort = config.listenPort {
                scratchpad[.listenPort] = String(listenPort)
            }
            if let mtu = config.mtu {
                scratchpad[.mtu] = String(mtu)
            }
            if !config.dns.isEmpty {
                scratchpad[.dns] = config.dns.map { $0.stringRepresentation }.joined(separator: ", ")
            }
            return scratchpad
        }

        //swiftlint:disable:next cyclomatic_complexity function_body_length
        func save() -> SaveResult<(String, InterfaceConfiguration)> {
            if let config = validatedConfiguration, let name = validatedName {
                return .saved((name, config))
            }
            fieldsWithError.removeAll()
            guard let name = scratchpad[.name]?.trimmingCharacters(in: .whitespacesAndNewlines), (!name.isEmpty) else {
                fieldsWithError.insert(.name)
                return .error(tr("alertInvalidInterfaceMessageNameRequired"))
            }
            guard let privateKeyString = scratchpad[.privateKey] else {
                fieldsWithError.insert(.privateKey)
                return .error(tr("alertInvalidInterfaceMessagePrivateKeyRequired"))
            }
            guard let privateKey = Data(base64Encoded: privateKeyString), privateKey.count == TunnelConfiguration.keyLength else {
                fieldsWithError.insert(.privateKey)
                return .error(tr("alertInvalidInterfaceMessagePrivateKeyInvalid"))
            }
            var config = InterfaceConfiguration(privateKey: privateKey)
            var errorMessages = [String]()
            if let addressesString = scratchpad[.addresses] {
                var addresses = [IPAddressRange]()
                for addressString in addressesString.splitToArray(trimmingCharacters: .whitespacesAndNewlines) {
                    if let address = IPAddressRange(from: addressString) {
                        addresses.append(address)
                    } else {
                        fieldsWithError.insert(.addresses)
                        errorMessages.append(tr("alertInvalidInterfaceMessageAddressInvalid"))
                    }
                }
                config.addresses = addresses
            }
            if let listenPortString = scratchpad[.listenPort] {
                if let listenPort = UInt16(listenPortString) {
                    config.listenPort = listenPort
                } else {
                    fieldsWithError.insert(.listenPort)
                    errorMessages.append(tr("alertInvalidInterfaceMessageListenPortInvalid"))
                }
            }
            if let mtuString = scratchpad[.mtu] {
                if let mtu = UInt16(mtuString), mtu >= 576 {
                    config.mtu = mtu
                } else {
                    fieldsWithError.insert(.mtu)
                    errorMessages.append(tr("alertInvalidInterfaceMessageMTUInvalid"))
                }
            }
            if let dnsString = scratchpad[.dns] {
                var dnsServers = [DNSServer]()
                for dnsServerString in dnsString.splitToArray(trimmingCharacters: .whitespacesAndNewlines) {
                    if let dnsServer = DNSServer(from: dnsServerString) {
                        dnsServers.append(dnsServer)
                    } else {
                        fieldsWithError.insert(.dns)
                        errorMessages.append(tr("alertInvalidInterfaceMessageDNSInvalid"))
                    }
                }
                config.dns = dnsServers
            }

            guard errorMessages.isEmpty else { return .error(errorMessages.first!) }

            validatedConfiguration = config
            validatedName = name
            return .saved((name, config))
        }

        func filterFieldsWithValueOrControl(interfaceFields: [InterfaceField]) -> [InterfaceField] {
            return interfaceFields.filter { field in
                if TunnelViewModel.interfaceFieldsWithControl.contains(field) {
                    return true
                }
                return !self[field].isEmpty
            }
        }

        func applyConfiguration(other: InterfaceConfiguration, otherName: String, changeHandler: ([InterfaceField: ChangeHandlers.FieldChange]) -> Void) {
            if scratchpad.isEmpty {
                populateScratchpad()
            }
            let otherScratchPad = InterfaceData.createScratchPad(from: other, name: otherName)
            var changes = [InterfaceField: ChangeHandlers.FieldChange]()
            for field in InterfaceField.allCases {
                switch (scratchpad[field] ?? "", otherScratchPad[field] ?? "") {
                case ("", ""):
                    break
                case ("", _):
                    changes[field] = .added
                case (_, ""):
                    changes[field] = .removed
                case (let this, let other):
                    if this != other {
                        changes[field] = .modified
                    }
                }
            }
            scratchpad = otherScratchPad
            if !changes.isEmpty {
                changeHandler(changes)
            }
        }
    }

    class PeerData {
        var index: Int
        var scratchpad = [PeerField: String]()
        var fieldsWithError = Set<PeerField>()
        var validatedConfiguration: PeerConfiguration?
        var publicKey: Data? {
            if let validatedConfiguration = validatedConfiguration {
                return validatedConfiguration.publicKey
            }
            if let scratchPadPublicKey = scratchpad[.publicKey] {
                return Data(base64Encoded: scratchPadPublicKey)
            }
            return nil
        }

        private(set) var shouldAllowExcludePrivateIPsControl = false
        private(set) var shouldStronglyRecommendDNS = false
        private(set) var excludePrivateIPsValue = false
        fileprivate var numberOfPeers = 0

        init(index: Int) {
            self.index = index
        }

        subscript(field: PeerField) -> String {
            get {
                if scratchpad.isEmpty {
                    populateScratchpad()
                }
                return scratchpad[field] ?? ""
            }
            set(stringValue) {
                if scratchpad.isEmpty {
                    populateScratchpad()
                }
                validatedConfiguration = nil
                if stringValue.isEmpty {
                    scratchpad.removeValue(forKey: field)
                } else {
                    scratchpad[field] = stringValue
                }
                if field == .allowedIPs {
                    updateExcludePrivateIPsFieldState()
                }
            }
        }

        func populateScratchpad() {
            guard let config = validatedConfiguration else { return }
            scratchpad = TunnelViewModel.PeerData.createScratchPad(from: config)
            updateExcludePrivateIPsFieldState()
        }

        private static func createScratchPad(from config: PeerConfiguration) -> [PeerField: String] {
            var scratchpad = [PeerField: String]()
            scratchpad[.publicKey] = config.publicKey.base64EncodedString()
            if let preSharedKey = config.preSharedKey {
                scratchpad[.preSharedKey] = preSharedKey.base64EncodedString()
            }
            if !config.allowedIPs.isEmpty {
                scratchpad[.allowedIPs] = config.allowedIPs.map { $0.stringRepresentation }.joined(separator: ", ")
            }
            if let endpoint = config.endpoint {
                scratchpad[.endpoint] = endpoint.stringRepresentation
            }
            if let persistentKeepAlive = config.persistentKeepAlive {
                scratchpad[.persistentKeepAlive] = String(persistentKeepAlive)
            }
            if let rxBytes = config.rxBytes {
                scratchpad[.rxBytes] = prettyBytes(rxBytes)
            }
            if let txBytes = config.txBytes {
                scratchpad[.txBytes] = prettyBytes(txBytes)
            }
            if let lastHandshakeTime = config.lastHandshakeTime {
                scratchpad[.lastHandshakeTime] = prettyTimeAgo(timestamp: lastHandshakeTime)
            }
            return scratchpad
        }

        //swiftlint:disable:next cyclomatic_complexity
        func save() -> SaveResult<PeerConfiguration> {
            if let validatedConfiguration = validatedConfiguration {
                return .saved(validatedConfiguration)
            }
            fieldsWithError.removeAll()
            guard let publicKeyString = scratchpad[.publicKey] else {
                fieldsWithError.insert(.publicKey)
                return .error(tr("alertInvalidPeerMessagePublicKeyRequired"))
            }
            guard let publicKey = Data(base64Encoded: publicKeyString), publicKey.count == TunnelConfiguration.keyLength else {
                fieldsWithError.insert(.publicKey)
                return .error(tr("alertInvalidPeerMessagePublicKeyInvalid"))
            }
            var config = PeerConfiguration(publicKey: publicKey)
            var errorMessages = [String]()
            if let preSharedKeyString = scratchpad[.preSharedKey] {
                if let preSharedKey = Data(base64Encoded: preSharedKeyString), preSharedKey.count == TunnelConfiguration.keyLength {
                    config.preSharedKey = preSharedKey
                } else {
                    fieldsWithError.insert(.preSharedKey)
                    errorMessages.append(tr("alertInvalidPeerMessagePreSharedKeyInvalid"))
                }
            }
            if let allowedIPsString = scratchpad[.allowedIPs] {
                var allowedIPs = [IPAddressRange]()
                for allowedIPString in allowedIPsString.splitToArray(trimmingCharacters: .whitespacesAndNewlines) {
                    if let allowedIP = IPAddressRange(from: allowedIPString) {
                        allowedIPs.append(allowedIP)
                    } else {
                        fieldsWithError.insert(.allowedIPs)
                        errorMessages.append(tr("alertInvalidPeerMessageAllowedIPsInvalid"))
                    }
                }
                config.allowedIPs = allowedIPs
            }
            if let endpointString = scratchpad[.endpoint] {
                if let endpoint = Endpoint(from: endpointString) {
                    config.endpoint = endpoint
                } else {
                    fieldsWithError.insert(.endpoint)
                    errorMessages.append(tr("alertInvalidPeerMessageEndpointInvalid"))
                }
            }
            if let persistentKeepAliveString = scratchpad[.persistentKeepAlive] {
                if let persistentKeepAlive = UInt16(persistentKeepAliveString) {
                    config.persistentKeepAlive = persistentKeepAlive
                } else {
                    fieldsWithError.insert(.persistentKeepAlive)
                    errorMessages.append(tr("alertInvalidPeerMessagePersistentKeepaliveInvalid"))
                }
            }

            guard errorMessages.isEmpty else { return .error(errorMessages.first!) }

            validatedConfiguration = config
            return .saved(config)
        }

        func filterFieldsWithValueOrControl(peerFields: [PeerField]) -> [PeerField] {
            return peerFields.filter { field in
                if TunnelViewModel.peerFieldsWithControl.contains(field) {
                    return true
                }
                return (!self[field].isEmpty)
            }
        }

        static let ipv4DefaultRouteString = "0.0.0.0/0"
        static let ipv4DefaultRouteModRFC1918String = [ // Set of all non-private IPv4 IPs
            "0.0.0.0/5", "8.0.0.0/7", "11.0.0.0/8", "12.0.0.0/6", "16.0.0.0/4", "32.0.0.0/3",
            "64.0.0.0/2", "128.0.0.0/3", "160.0.0.0/5", "168.0.0.0/6", "172.0.0.0/12",
            "172.32.0.0/11", "172.64.0.0/10", "172.128.0.0/9", "173.0.0.0/8", "174.0.0.0/7",
            "176.0.0.0/4", "192.0.0.0/9", "192.128.0.0/11", "192.160.0.0/13", "192.169.0.0/16",
            "192.170.0.0/15", "192.172.0.0/14", "192.176.0.0/12", "192.192.0.0/10",
            "193.0.0.0/8", "194.0.0.0/7", "196.0.0.0/6", "200.0.0.0/5", "208.0.0.0/4"
        ]

        func updateExcludePrivateIPsFieldState() {
            if scratchpad.isEmpty {
                populateScratchpad()
            }
            let allowedIPStrings = Set<String>(scratchpad[.allowedIPs].splitToArray(trimmingCharacters: .whitespacesAndNewlines))
            shouldStronglyRecommendDNS = allowedIPStrings.contains(TunnelViewModel.PeerData.ipv4DefaultRouteString) || allowedIPStrings.isSuperset(of: TunnelViewModel.PeerData.ipv4DefaultRouteModRFC1918String)
            guard numberOfPeers == 1 else {
                shouldAllowExcludePrivateIPsControl = false
                excludePrivateIPsValue = false
                return
            }
            if allowedIPStrings.contains(TunnelViewModel.PeerData.ipv4DefaultRouteString) {
                shouldAllowExcludePrivateIPsControl = true
                excludePrivateIPsValue = false
            } else if allowedIPStrings.isSuperset(of: TunnelViewModel.PeerData.ipv4DefaultRouteModRFC1918String) {
                shouldAllowExcludePrivateIPsControl = true
                excludePrivateIPsValue = true
            } else {
                shouldAllowExcludePrivateIPsControl = false
                excludePrivateIPsValue = false
            }
        }

        func excludePrivateIPsValueChanged(isOn: Bool, dnsServers: String) {
            let allowedIPStrings = scratchpad[.allowedIPs].splitToArray(trimmingCharacters: .whitespacesAndNewlines)
            let dnsServerStrings = dnsServers.splitToArray(trimmingCharacters: .whitespacesAndNewlines)
            let ipv6Addresses = allowedIPStrings.filter { $0.contains(":") }
            let modifiedAllowedIPStrings: [String]
            if isOn {
                modifiedAllowedIPStrings = ipv6Addresses + TunnelViewModel.PeerData.ipv4DefaultRouteModRFC1918String + dnsServerStrings
            } else {
                modifiedAllowedIPStrings = ipv6Addresses + [TunnelViewModel.PeerData.ipv4DefaultRouteString]
            }
            scratchpad[.allowedIPs] = modifiedAllowedIPStrings.joined(separator: ", ")
            validatedConfiguration = nil
            excludePrivateIPsValue = isOn
        }

        func applyConfiguration(other: PeerConfiguration, peerIndex: Int, changeHandler: (Int, [PeerField: ChangeHandlers.FieldChange]) -> Void) {
            if scratchpad.isEmpty {
                populateScratchpad()
            }
            let otherScratchPad = PeerData.createScratchPad(from: other)
            var changes = [PeerField: ChangeHandlers.FieldChange]()
            for field in PeerField.allCases {
                switch (scratchpad[field] ?? "", otherScratchPad[field] ?? "") {
                case ("", ""):
                    break
                case ("", _):
                    changes[field] = .added
                case (_, ""):
                    changes[field] = .removed
                case (let this, let other):
                    if this != other {
                        changes[field] = .modified
                    }
                }
            }
            scratchpad = otherScratchPad
            if !changes.isEmpty {
                changeHandler(peerIndex, changes)
            }
        }
    }

    enum SaveResult<Configuration> {
        case saved(Configuration)
        case error(String)
    }

    private(set) var interfaceData: InterfaceData
    private(set) var peersData: [PeerData]

    init(tunnelConfiguration: TunnelConfiguration?) {
        let interfaceData = InterfaceData()
        var peersData = [PeerData]()
        if let tunnelConfiguration = tunnelConfiguration {
            interfaceData.validatedConfiguration = tunnelConfiguration.interface
            interfaceData.validatedName = tunnelConfiguration.name
            for (index, peerConfiguration) in tunnelConfiguration.peers.enumerated() {
                let peerData = PeerData(index: index)
                peerData.validatedConfiguration = peerConfiguration
                peersData.append(peerData)
            }
        }
        let numberOfPeers = peersData.count
        for peerData in peersData {
            peerData.numberOfPeers = numberOfPeers
            peerData.updateExcludePrivateIPsFieldState()
        }
        self.interfaceData = interfaceData
        self.peersData = peersData
    }

    func appendEmptyPeer() {
        let peer = PeerData(index: peersData.count)
        peersData.append(peer)
        for peer in peersData {
            peer.numberOfPeers = peersData.count
            peer.updateExcludePrivateIPsFieldState()
        }
    }

    func deletePeer(peer: PeerData) {
        let removedPeer = peersData.remove(at: peer.index)
        assert(removedPeer.index == peer.index)
        for peer in peersData[peer.index ..< peersData.count] {
            assert(peer.index > 0)
            peer.index -= 1
        }
        for peer in peersData {
            peer.numberOfPeers = peersData.count
            peer.updateExcludePrivateIPsFieldState()
        }
    }

    func save() -> SaveResult<TunnelConfiguration> {
        let interfaceSaveResult = interfaceData.save()
        let peerSaveResults = peersData.map { $0.save() } // Save all, to help mark erroring fields in red
        switch interfaceSaveResult {
        case .error(let errorMessage):
            return .error(errorMessage)
        case .saved(let interfaceConfiguration):
            var peerConfigurations = [PeerConfiguration]()
            peerConfigurations.reserveCapacity(peerSaveResults.count)
            for peerSaveResult in peerSaveResults {
                switch peerSaveResult {
                case .error(let errorMessage):
                    return .error(errorMessage)
                case .saved(let peerConfiguration):
                    peerConfigurations.append(peerConfiguration)
                }
            }

            let peerPublicKeysArray = peerConfigurations.map { $0.publicKey }
            let peerPublicKeysSet = Set<Data>(peerPublicKeysArray)
            if peerPublicKeysArray.count != peerPublicKeysSet.count {
                return .error(tr("alertInvalidPeerMessagePublicKeyDuplicated"))
            }

            let tunnelConfiguration = TunnelConfiguration(name: interfaceConfiguration.0, interface: interfaceConfiguration.1, peers: peerConfigurations)
            return .saved(tunnelConfiguration)
        }
    }

    func applyConfiguration(other: TunnelConfiguration, changeHandlers: ChangeHandlers) {
        // Replaces current data with data from other TunnelConfiguration, ignoring any changes in peer ordering.
        // Change handler callbacks are processed in the following order, which is designed to work with both the
        // UITableView way (modify - delete - insert) and the NSTableView way (indices are based on past operations):
        //   - interfaceChanged
        //   - peerChangedAt
        //   - peersRemovedAt
        //   - peersInsertedAt

        interfaceData.applyConfiguration(other: other.interface, otherName: other.name ?? "", changeHandler: changeHandlers.interfaceChanged)

        for otherPeer in other.peers {
            if let peersDataIndex = peersData.firstIndex(where: { $0.publicKey == otherPeer.publicKey }) {
                let peerData = peersData[peersDataIndex]
                peerData.applyConfiguration(other: otherPeer, peerIndex: peersDataIndex, changeHandler: changeHandlers.peerChangedAt)
            }
        }

        var removedPeerIndices = [Int]()
        for (index, peerData) in peersData.enumerated().reversed() {
            if let peerPublicKey = peerData.publicKey, !other.peers.contains(where: { $0.publicKey == peerPublicKey}) {
                removedPeerIndices.append(index)
                peersData.remove(at: index)
            }
        }
        if !removedPeerIndices.isEmpty {
            changeHandlers.peersRemovedAt(removedPeerIndices)
        }

        var addedPeerIndices = [Int]()
        for otherPeer in other.peers {
            if !peersData.contains(where: { $0.publicKey == otherPeer.publicKey }) {
                addedPeerIndices.append(peersData.count)
                let peerData = PeerData(index: peersData.count)
                peerData.validatedConfiguration = otherPeer
                peersData.append(peerData)
            }
        }
        if !addedPeerIndices.isEmpty {
            changeHandlers.peersInsertedAt(addedPeerIndices)
        }

        for (index, peer) in peersData.enumerated() {
            peer.index = index
            peer.numberOfPeers = peersData.count
            peer.updateExcludePrivateIPsFieldState()
        }
    }
}

extension TunnelViewModel {
    static func activateOnDemandOptionText(for activateOnDemandOption: ActivateOnDemandOption) -> String {
        switch activateOnDemandOption {
        case .none:
            return tr("tunnelOnDemandOptionOff")
        case .useOnDemandOverWiFiOnly:
            return tr("tunnelOnDemandOptionWiFiOnly")
        #if os(iOS)
        case .useOnDemandOverWiFiOrCellular:
            return tr("tunnelOnDemandOptionWiFiOrCellular")
        case .useOnDemandOverCellularOnly:
            return tr("tunnelOnDemandOptionCellularOnly")
        #elseif os(macOS)
        case .useOnDemandOverWiFiOrEthernet:
            return tr("tunnelOnDemandOptionWiFiOrEthernet")
        case .useOnDemandOverEthernetOnly:
            return tr("tunnelOnDemandOptionEthernetOnly")
        #else
        #error("Unimplemented")
        #endif
        }
    }

    static func activateOnDemandDetailText(for activateOnDemandSetting: ActivateOnDemandSetting?) -> String {
        if let activateOnDemandSetting = activateOnDemandSetting {
            if activateOnDemandSetting.isActivateOnDemandEnabled {
                return TunnelViewModel.activateOnDemandOptionText(for: activateOnDemandSetting.activateOnDemandOption)
            } else {
                return TunnelViewModel.activateOnDemandOptionText(for: .none)
            }
        } else {
            return TunnelViewModel.activateOnDemandOptionText(for: .none)
        }
    }

    static func defaultActivateOnDemandOption() -> ActivateOnDemandOption {
        #if os(iOS)
        return .useOnDemandOverWiFiOrCellular
        #elseif os(macOS)
        return .useOnDemandOverWiFiOrEthernet
        #else
        #error("Unimplemented")
        #endif
    }
}

private func prettyBytes(_ bytes: UInt64) -> String {
    switch bytes {
    case 0..<1024:
        return "\(bytes) B"
    case 1024 ..< (1024 * 1024):
        return String(format: "%.2f", Double(bytes) / 1024) + " KiB"
    case 1024 ..< (1024 * 1024 * 1024):
        return String(format: "%.2f", Double(bytes) / (1024 * 1024)) + " MiB"
    case 1024 ..< (1024 * 1024 * 1024 * 1024):
        return String(format: "%.2f", Double(bytes) / (1024 * 1024 * 1024)) + " GiB"
    default:
        return String(format: "%.2f", Double(bytes) / (1024 * 1024 * 1024 * 1024)) + " TiB"
    }
}

private func prettyTimeAgo(timestamp: Date) -> String {
    let now = Date()
    let timeInterval = Int64(now.timeIntervalSince(timestamp))
    switch timeInterval {
    case ..<0: return tr("tunnelHandshakeTimestampSystemClockBackward")
    case 0: return tr("tunnelHandshakeTimestampNow")
    default:
        return tr(format: "tunnelHandshakeTimestampAgo (%@)", prettyTime(secondsLeft: timeInterval))
    }
}

private func prettyTime(secondsLeft: Int64) -> String {
    var left = secondsLeft
    var timeStrings = [String]()
    let years = left / (365 * 24 * 60 * 60)
    left = left % (365 * 24 * 60 * 60)
    let days = left / (24 * 60 * 60)
    left = left % (24 * 60 * 60)
    let hours = left / (60 * 60)
    left = left % (60 * 60)
    let minutes = left / 60
    let seconds = left % 60

    #if os(iOS)
    if years > 0 {
        return years == 1 ? tr(format: "tunnelHandshakeTimestampYear (%d)", years) : tr(format: "tunnelHandshakeTimestampYears (%d)", years)
    }
    if days > 0 {
        return days == 1 ? tr(format: "tunnelHandshakeTimestampDay (%d)", days) : tr(format: "tunnelHandshakeTimestampDays (%d)", days)
    }
    if hours > 0 {
        let hhmmss = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        return tr(format: "tunnelHandshakeTimestampHours hh:mm:ss (%@)", hhmmss)
    }
    if minutes > 0 {
        let mmss = String(format: "%02d:%02d", minutes, seconds)
        return tr(format: "tunnelHandshakeTimestampMinutes mm:ss (%@)", mmss)
    }
    return seconds == 1 ? tr(format: "tunnelHandshakeTimestampSecond (%d)", seconds) : tr(format: "tunnelHandshakeTimestampSeconds (%d)", seconds)
    #elseif os(macOS)
    if years > 0 {
        timeStrings.append(years == 1 ? tr(format: "tunnelHandshakeTimestampYear (%d)", years) : tr(format: "tunnelHandshakeTimestampYears (%d)", years))
    }
    if days > 0 {
        timeStrings.append(days == 1 ? tr(format: "tunnelHandshakeTimestampDay (%d)", days) : tr(format: "tunnelHandshakeTimestampDays (%d)", days))
    }
    if hours > 0 {
        timeStrings.append(hours == 1 ? tr(format: "tunnelHandshakeTimestampHour (%d)", hours) : tr(format: "tunnelHandshakeTimestampHours (%d)", hours))
    }
    if minutes > 0 {
        timeStrings.append(minutes == 1 ? tr(format: "tunnelHandshakeTimestampMinute (%d)", minutes) : tr(format: "tunnelHandshakeTimestampMinutes (%d)", minutes))
    }
    if seconds > 0 {
        timeStrings.append(seconds == 1 ? tr(format: "tunnelHandshakeTimestampSecond (%d)", seconds) : tr(format: "tunnelHandshakeTimestampSeconds (%d)", seconds))
    }
    return timeStrings.joined(separator: ", ")
    #endif
}
