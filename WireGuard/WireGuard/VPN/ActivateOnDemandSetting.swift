// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import NetworkExtension

struct ActivateOnDemandSetting {
    var isActivateOnDemandEnabled: Bool
    var activateOnDemandOption: ActivateOnDemandOption
}

enum ActivateOnDemandOption {
    case none // Valid only when isActivateOnDemandEnabled is false
    case useOnDemandOverWifiOrCellular
    case useOnDemandOverWifiOnly
    case useOnDemandOverCellularOnly
}

extension ActivateOnDemandSetting {
    func apply(on tunnelProviderManager: NETunnelProviderManager) {
        tunnelProviderManager.isOnDemandEnabled = isActivateOnDemandEnabled
        let rules: [NEOnDemandRule]?
        let connectRule = NEOnDemandRuleConnect()
        let disconnectRule = NEOnDemandRuleDisconnect()
        switch (activateOnDemandOption) {
        case .none:
            rules = nil
        case .useOnDemandOverWifiOrCellular:
            rules = [connectRule]
        case .useOnDemandOverWifiOnly:
            connectRule.interfaceTypeMatch = .wiFi
            disconnectRule.interfaceTypeMatch = .cellular
            rules = [connectRule, disconnectRule]
        case .useOnDemandOverCellularOnly:
            connectRule.interfaceTypeMatch = .cellular
            disconnectRule.interfaceTypeMatch = .wiFi
            rules = [connectRule, disconnectRule]
        }
        tunnelProviderManager.onDemandRules = rules
    }

    init(from tunnelProviderManager: NETunnelProviderManager) {
        let rules = tunnelProviderManager.onDemandRules ?? []
        let activateOnDemandOption: ActivateOnDemandOption
        switch (rules.count) {
        case 0:
            activateOnDemandOption = .none
        case 1:
            let rule = rules[0]
            precondition(rule.action == .connect)
            activateOnDemandOption = .useOnDemandOverWifiOrCellular
        case 2:
            let connectRule = rules.first(where: { $0.action == .connect })!
            let disconnectRule = rules.first(where: { $0.action == .disconnect })!
            if (connectRule.interfaceTypeMatch == .wiFi && disconnectRule.interfaceTypeMatch == .cellular) {
                activateOnDemandOption = .useOnDemandOverWifiOnly
            } else if (connectRule.interfaceTypeMatch == .cellular && disconnectRule.interfaceTypeMatch == .wiFi) {
                activateOnDemandOption = .useOnDemandOverCellularOnly
            } else {
                fatalError("Unexpected onDemandRules set on tunnel provider manager")
            }
        default:
            fatalError("Unexpected number of onDemandRules set on tunnel provider manager")
        }
        self.activateOnDemandOption = activateOnDemandOption
        if (activateOnDemandOption == .none) {
            self.isActivateOnDemandEnabled = false
        } else {
            self.isActivateOnDemandEnabled = tunnelProviderManager.isOnDemandEnabled
        }
    }
}

extension ActivateOnDemandSetting {
    static var defaultSetting = ActivateOnDemandSetting(isActivateOnDemandEnabled: false, activateOnDemandOption: .none)
}
