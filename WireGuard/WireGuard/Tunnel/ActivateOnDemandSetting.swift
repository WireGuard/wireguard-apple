// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import NetworkExtension

struct ActivateOnDemandSetting {
    var isActivateOnDemandEnabled: Bool
    var activateOnDemandOption: ActivateOnDemandOption
}

enum ActivateOnDemandOption {
    case none // Valid only when isActivateOnDemandEnabled is false
    case useOnDemandOverWiFiOnly
    #if os(iOS)
    case useOnDemandOverWiFiOrCellular
    case useOnDemandOverCellularOnly
    #elseif os(macOS)
    case useOnDemandOverWiFiOrEthernet
    case useOnDemandOverEthernetOnly
    #else
    #error("Unimplemented")
    #endif
}

extension ActivateOnDemandSetting {
    func apply(on tunnelProviderManager: NETunnelProviderManager) {
        tunnelProviderManager.isOnDemandEnabled = isActivateOnDemandEnabled
        let rules: [NEOnDemandRule]?
        let connectRule = NEOnDemandRuleConnect()
        let disconnectRule = NEOnDemandRuleDisconnect()
        switch activateOnDemandOption {
        case .none:
            rules = nil
        #if os(iOS)
        case .useOnDemandOverWiFiOrCellular:
            rules = [connectRule]
        case .useOnDemandOverWiFiOnly:
            connectRule.interfaceTypeMatch = .wiFi
            disconnectRule.interfaceTypeMatch = .cellular
            rules = [connectRule, disconnectRule]
        case .useOnDemandOverCellularOnly:
            connectRule.interfaceTypeMatch = .cellular
            disconnectRule.interfaceTypeMatch = .wiFi
            rules = [connectRule, disconnectRule]
        #elseif os(macOS)
        case .useOnDemandOverWiFiOrEthernet:
            rules = [connectRule]
        case .useOnDemandOverWiFiOnly:
            connectRule.interfaceTypeMatch = .wiFi
            disconnectRule.interfaceTypeMatch = .ethernet
            rules = [connectRule, disconnectRule]
        case .useOnDemandOverEthernetOnly:
            connectRule.interfaceTypeMatch = .ethernet
            disconnectRule.interfaceTypeMatch = .wiFi
            rules = [connectRule, disconnectRule]
        #else
        #error("Unimplemented")
        #endif
        }
        tunnelProviderManager.onDemandRules = rules
    }

    init(from tunnelProviderManager: NETunnelProviderManager) {
        let rules = tunnelProviderManager.onDemandRules ?? []
        #if os(iOS)
        let otherInterfaceType: NEOnDemandRuleInterfaceType = .cellular
        let useWiFiOrOtherOption: ActivateOnDemandOption = .useOnDemandOverWiFiOrCellular
        let useOtherOnlyOption: ActivateOnDemandOption = .useOnDemandOverCellularOnly
        #elseif os(macOS)
        let otherInterfaceType: NEOnDemandRuleInterfaceType = .ethernet
        let useWiFiOrOtherOption: ActivateOnDemandOption = .useOnDemandOverWiFiOrEthernet
        let useOtherOnlyOption: ActivateOnDemandOption = .useOnDemandOverEthernetOnly
        #else
        #error("Unimplemented")
        #endif
        let activateOnDemandOption: ActivateOnDemandOption
        switch rules.count {
        case 0:
            activateOnDemandOption = .none
        case 1:
            let rule = rules[0]
            precondition(rule.action == .connect)
            activateOnDemandOption = useWiFiOrOtherOption
        case 2:
            let connectRule = rules.first(where: { $0.action == .connect })!
            let disconnectRule = rules.first(where: { $0.action == .disconnect })!
            if connectRule.interfaceTypeMatch == .wiFi && disconnectRule.interfaceTypeMatch == otherInterfaceType {
                activateOnDemandOption = .useOnDemandOverWiFiOnly
            } else if connectRule.interfaceTypeMatch == otherInterfaceType && disconnectRule.interfaceTypeMatch == .wiFi {
                activateOnDemandOption = useOtherOnlyOption
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
