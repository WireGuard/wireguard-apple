// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import NetworkExtension

struct ActivateOnDemandSetting {
    var isActivateOnDemandEnabled: Bool
    var activateOnDemandOption: ActivateOnDemandOption
}

enum ActivateOnDemandOption {
    case none // Valid only when isActivateOnDemandEnabled is false
    case wiFiInterfaceOnly
    case nonWiFiInterfaceOnly
    case anyInterface
}

#if os(iOS)
private let nonWiFiInterfaceType: NEOnDemandRuleInterfaceType = .cellular
#elseif os(macOS)
private let nonWiFiInterfaceType: NEOnDemandRuleInterfaceType = .ethernet
#else
#error("Unimplemented")
#endif

extension ActivateOnDemandSetting {
    func apply(on tunnelProviderManager: NETunnelProviderManager) {
        tunnelProviderManager.isOnDemandEnabled = isActivateOnDemandEnabled
        let rules: [NEOnDemandRule]?
        let connectRule = NEOnDemandRuleConnect()
        let disconnectRule = NEOnDemandRuleDisconnect()
        switch activateOnDemandOption {
        case .none:
            rules = nil
        case .wiFiInterfaceOnly:
            connectRule.interfaceTypeMatch = .wiFi
            disconnectRule.interfaceTypeMatch = nonWiFiInterfaceType
            rules = [connectRule, disconnectRule]
        case .nonWiFiInterfaceOnly:
            connectRule.interfaceTypeMatch = nonWiFiInterfaceType
            disconnectRule.interfaceTypeMatch = .wiFi
            rules = [connectRule, disconnectRule]
        case .anyInterface:
            rules = [connectRule]
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
            activateOnDemandOption = .anyInterface
        case 2:
            let connectRule = rules.first(where: { $0.action == .connect })!
            let disconnectRule = rules.first(where: { $0.action == .disconnect })!
            if connectRule.interfaceTypeMatch == .wiFi && disconnectRule.interfaceTypeMatch == nonWiFiInterfaceType {
                activateOnDemandOption = .wiFiInterfaceOnly
            } else if connectRule.interfaceTypeMatch == nonWiFiInterfaceType && disconnectRule.interfaceTypeMatch == .wiFi {
                activateOnDemandOption = .nonWiFiInterfaceOnly
            } else {
                fatalError("Unexpected onDemandRules set on tunnel provider manager")
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
