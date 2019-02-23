// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import NetworkExtension

struct ActivateOnDemandSetting {
    var isActivateOnDemandEnabled: Bool
    var activateOnDemandOption: ActivateOnDemandOption
}

enum ActivateOnDemandOption: Equatable {
    case none // Valid only when isActivateOnDemandEnabled is false
    case wiFiInterfaceOnly(ActivateOnDemandSSIDOption)
    case nonWiFiInterfaceOnly
    case anyInterface(ActivateOnDemandSSIDOption)
}

#if os(iOS)
private let nonWiFiInterfaceType: NEOnDemandRuleInterfaceType = .cellular
#elseif os(macOS)
private let nonWiFiInterfaceType: NEOnDemandRuleInterfaceType = .ethernet
#else
#error("Unimplemented")
#endif

enum ActivateOnDemandSSIDOption: Equatable {
    case anySSID
    case onlySpecificSSIDs([String])
    case exceptSpecificSSIDs([String])
}

extension ActivateOnDemandSetting {
    func apply(on tunnelProviderManager: NETunnelProviderManager) {
        tunnelProviderManager.isOnDemandEnabled = isActivateOnDemandEnabled
        let rules: [NEOnDemandRule]?
        switch activateOnDemandOption {
        case .none:
            rules = nil
        case .wiFiInterfaceOnly(let ssidOption):
            rules = ssidOnDemandRules(option: ssidOption) + [NEOnDemandRuleDisconnect(interfaceType: nonWiFiInterfaceType)]
        case .nonWiFiInterfaceOnly:
            rules = [NEOnDemandRuleConnect(interfaceType: nonWiFiInterfaceType), NEOnDemandRuleDisconnect(interfaceType: .wiFi)]
        case .anyInterface(let ssidOption):
            if case .anySSID = ssidOption {
                rules = [NEOnDemandRuleConnect(interfaceType: .any)]
            } else {
                rules = ssidOnDemandRules(option: ssidOption) + [NEOnDemandRuleConnect(interfaceType: nonWiFiInterfaceType)]
            }
        }
        tunnelProviderManager.onDemandRules = rules
    }

    init(from tunnelProviderManager: NETunnelProviderManager) {
        let rules = tunnelProviderManager.onDemandRules ?? []
        let activateOnDemandOption: ActivateOnDemandOption
        switch rules.count {
        case 0:
            activateOnDemandOption = .none
        case 1:
            let rule = rules[0]
            precondition(rule.action == .connect)
            activateOnDemandOption = .anyInterface(.anySSID)
        case 2:
            let connectRule = rules.first(where: { $0.action == .connect })!
            let disconnectRule = rules.first(where: { $0.action == .disconnect })!
            if connectRule.interfaceTypeMatch == .wiFi && disconnectRule.interfaceTypeMatch == nonWiFiInterfaceType {
                activateOnDemandOption = .wiFiInterfaceOnly(.anySSID)
            } else if connectRule.interfaceTypeMatch == nonWiFiInterfaceType && disconnectRule.interfaceTypeMatch == .wiFi {
                activateOnDemandOption = .nonWiFiInterfaceOnly
            } else {
                fatalError("Unexpected onDemandRules set on tunnel provider manager")
            }
        case 3:
            let ssidRule = rules.first(where: { $0.interfaceTypeMatch == .wiFi && $0.ssidMatch != nil })!
            let nonWiFiRule = rules.first(where: { $0.interfaceTypeMatch == nonWiFiInterfaceType })!
            let ssids = ssidRule.ssidMatch!
            switch (ssidRule.action, nonWiFiRule.action) {
            case (.connect, .connect):
                activateOnDemandOption = .anyInterface(.onlySpecificSSIDs(ssids))
            case (.connect, .disconnect):
                activateOnDemandOption = .wiFiInterfaceOnly(.onlySpecificSSIDs(ssids))
            case (.disconnect, .connect):
                activateOnDemandOption = .anyInterface(.exceptSpecificSSIDs(ssids))
            case (.disconnect, .disconnect):
                activateOnDemandOption = .wiFiInterfaceOnly(.exceptSpecificSSIDs(ssids))
            default:
                fatalError("Unexpected SSID onDemandRules set on tunnel provider manager")
            }
        default:
            fatalError("Unexpected number of onDemandRules set on tunnel provider manager")
        }

        self.activateOnDemandOption = activateOnDemandOption
        if activateOnDemandOption == .none {
            isActivateOnDemandEnabled = false
        } else {
            isActivateOnDemandEnabled = tunnelProviderManager.isOnDemandEnabled
        }
    }
}

extension ActivateOnDemandSetting {
    static var defaultSetting = ActivateOnDemandSetting(isActivateOnDemandEnabled: false, activateOnDemandOption: .none)
}

private extension NEOnDemandRuleConnect {
    convenience init(interfaceType: NEOnDemandRuleInterfaceType, ssids: [String]? = nil) {
        self.init()
        interfaceTypeMatch = interfaceType
        ssidMatch = ssids
    }
}

private extension NEOnDemandRuleDisconnect {
    convenience init(interfaceType: NEOnDemandRuleInterfaceType, ssids: [String]? = nil) {
        self.init()
        interfaceTypeMatch = interfaceType
        ssidMatch = ssids
    }
}

private func ssidOnDemandRules(option: ActivateOnDemandSSIDOption) -> [NEOnDemandRule] {
    switch option {
    case .anySSID:
        return [NEOnDemandRuleConnect(interfaceType: .wiFi)]
    case .onlySpecificSSIDs(let ssids):
        assert(!ssids.isEmpty)
        return [NEOnDemandRuleConnect(interfaceType: .wiFi, ssids: ssids),
                NEOnDemandRuleDisconnect(interfaceType: .wiFi)]
    case .exceptSpecificSSIDs(let ssids):
        return [NEOnDemandRuleDisconnect(interfaceType: .wiFi, ssids: ssids),
                NEOnDemandRuleConnect(interfaceType: .wiFi)]
    }
}
