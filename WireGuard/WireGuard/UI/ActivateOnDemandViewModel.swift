// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation

class ActivateOnDemandViewModel {
    enum OnDemandField {
        case nonWiFiInterface
        case wiFiInterface
        case ssidDescription
        case ssidEdit

        var localizedUIString: String {
            switch self {
            case .nonWiFiInterface:
                #if os(iOS)
                return tr("tunnelOnDemandCellular")
                #elseif os(macOS)
                return tr("tunnelOnDemandEthernet")
                #else
                #error("Unimplemented")
                #endif
            case .wiFiInterface: return tr("tunnelOnDemandWiFi")
            case .ssidDescription: return tr("tunnelOnDemandSSIDDescription")
            case .ssidEdit: return tr("tunnelOnDemandSSIDEdit")
            }
        }
    }

    enum OnDemandSSIDOption {
        case anySSID
        case onlySpecificSSIDs
        case exceptSpecificSSIDs

        var localizedUIString: String {
            switch self {
            case .anySSID: return tr("tunnelOnDemandAnySSID")
            case .onlySpecificSSIDs: return tr("tunnelOnDemandOnlySelectedSSIDs")
            case .exceptSpecificSSIDs: return tr("tunnelOnDemandExceptSelectedSSIDs")
            }
        }
    }

    var isNonWiFiInterfaceEnabled = false
    var isWiFiInterfaceEnabled = false
    var selectedSSIDs = [String]()
    var ssidOption: OnDemandSSIDOption = .anySSID
}

extension ActivateOnDemandViewModel {
    convenience init(from option: ActivateOnDemandOption) {
        self.init()
        switch option {
        case .none:
            break
        case .wiFiInterfaceOnly(let onDemandSSIDOption):
            isWiFiInterfaceEnabled = true
            (ssidOption, selectedSSIDs) = ssidViewModel(from: onDemandSSIDOption)
        case .nonWiFiInterfaceOnly:
            isNonWiFiInterfaceEnabled = true
        case .anyInterface(let onDemandSSIDOption):
            isWiFiInterfaceEnabled = true
            isNonWiFiInterfaceEnabled = true
            (ssidOption, selectedSSIDs) = ssidViewModel(from: onDemandSSIDOption)
        }
    }

    func toOnDemandOption() -> ActivateOnDemandOption {
        switch (isWiFiInterfaceEnabled, isNonWiFiInterfaceEnabled) {
        case (false, false):
            return .none
        case (false, true):
            return .nonWiFiInterfaceOnly
        case (true, false):
            return .wiFiInterfaceOnly(toSSIDOption())
        case (true, true):
            return .anyInterface(toSSIDOption())
        }
    }
}

extension ActivateOnDemandViewModel {
    func isEnabled(field: OnDemandField) -> Bool {
        switch field {
        case .nonWiFiInterface:
            return isNonWiFiInterfaceEnabled
        case .wiFiInterface:
            return isWiFiInterfaceEnabled
        default:
            return false
        }
    }

    func setEnabled(field: OnDemandField, isEnabled: Bool) {
        switch field {
        case .nonWiFiInterface:
            isNonWiFiInterfaceEnabled = isEnabled
        case .wiFiInterface:
            isWiFiInterfaceEnabled = isEnabled
        default:
            break
        }
    }
}

private extension ActivateOnDemandViewModel {
    func ssidViewModel(from ssidOption: ActivateOnDemandSSIDOption) -> (OnDemandSSIDOption, [String]) {
        switch ssidOption {
        case .anySSID:
            return (.anySSID, [])
        case .onlySpecificSSIDs(let ssids):
            return (.onlySpecificSSIDs, ssids)
        case .exceptSpecificSSIDs(let ssids):
            return (.exceptSpecificSSIDs, ssids)
        }
    }

    func toSSIDOption() -> ActivateOnDemandSSIDOption {
        switch ssidOption {
        case .anySSID:
            return .anySSID
        case .onlySpecificSSIDs:
            return .onlySpecificSSIDs(selectedSSIDs)
        case .exceptSpecificSSIDs:
            return .exceptSpecificSSIDs(selectedSSIDs)
        }
    }
}
