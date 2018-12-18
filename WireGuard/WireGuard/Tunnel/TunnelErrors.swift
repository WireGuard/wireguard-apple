// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import NetworkExtension

enum TunnelsManagerError: WireGuardAppError {
    case tunnelNameEmpty
    case tunnelAlreadyExistsWithThatName
    case systemErrorOnListingTunnels(systemError: Error)
    case systemErrorOnAddTunnel(systemError: Error)
    case systemErrorOnModifyTunnel(systemError: Error)
    case systemErrorOnRemoveTunnel(systemError: Error)

    var alertText: AlertText {
        switch self {
        case .tunnelNameEmpty:
            return ("No name provided", "Cannot create tunnel with an empty name")
        case .tunnelAlreadyExistsWithThatName:
            return ("Name already exists", "A tunnel with that name already exists")
        case .systemErrorOnListingTunnels(let systemError):
            return ("Unable to list tunnels", systemError.UIString)
        case .systemErrorOnAddTunnel(let systemError):
            return ("Unable to create tunnel", systemError.UIString)
        case .systemErrorOnModifyTunnel(let systemError):
            return ("Unable to modify tunnel", systemError.UIString)
        case .systemErrorOnRemoveTunnel(let systemError):
            return ("Unable to remove tunnel", systemError.UIString)
        }
    }
}

enum TunnelsManagerActivationAttemptError: WireGuardAppError {
    case tunnelIsNotInactive
    case anotherTunnelIsOperational(otherTunnelName: String)
    case failedWhileStarting(systemError: Error) // startTunnel() throwed
    case failedWhileSaving(systemError: Error) // save config after re-enabling throwed
    case failedWhileLoading(systemError: Error) // reloading config throwed
    case failedBecauseOfTooManyErrors(lastSystemError: Error) // recursion limit reached

    var alertText: AlertText {
        switch self {
        case .tunnelIsNotInactive:
            return ("Activation failure", "The tunnel is already active or in the process of being activated")
        case .anotherTunnelIsOperational(let otherTunnelName):
            return ("Activation failure", "Please disconnect '\(otherTunnelName)' before enabling this tunnel.")
        case .failedWhileStarting(let systemError),
             .failedWhileSaving(let systemError),
             .failedWhileLoading(let systemError),
             .failedBecauseOfTooManyErrors(let systemError):
            return ("Activation failure", "The tunnel could not be activated. " + systemError.UIString)
        }
    }
}

enum TunnelsManagerActivationError: WireGuardAppError {
    case activationFailed
    case activationFailedWithExtensionError(title: String, message: String)
    var alertText: AlertText {
        switch self {
        case .activationFailed:
            return ("Activation failure", "The tunnel could not be activated. Please ensure that you are connected to the Internet.")
        case .activationFailedWithExtensionError(let title, let message):
            return (title, message)
        }
    }
}

extension Error {
    var UIString: String {
        if let systemError = self as? NEVPNError {
            switch systemError {
            case NEVPNError.configurationInvalid:
                return "The configuration is invalid."
            case NEVPNError.configurationDisabled:
                return "The configuration is disabled."
            case NEVPNError.connectionFailed:
                return "The connection failed."
            case NEVPNError.configurationStale:
                return "The configuration is stale."
            case NEVPNError.configurationReadWriteFailed:
                return "Reading or writing the configuration failed."
            case NEVPNError.configurationUnknown:
                return "Unknown system error."
            default:
                return ""
            }
        } else {
            return localizedDescription
        }
    }
}
