// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Cocoa

// We have this in a separate file because we don't want the network extension
// code to see WireGuardAppError and tr(). Also, this extension is used only on macOS.

extension TunnelConfiguration.ParseError: WireGuardAppError {
    var alertText: AlertText {
        switch self {
        case .invalidLine(let line):
            return (tr(format: "macAlertInvalidLine (%@)", String(line)), "")
        case .noInterface:
            return (tr("macAlertNoInterface"), "")
        case .multipleInterfaces:
            return (tr("macAlertMultipleInterfaces"), "")
        case .interfaceHasNoPrivateKey:
            return (tr("alertInvalidInterfaceMessagePrivateKeyRequired"), tr("alertInvalidInterfaceMessagePrivateKeyInvalid"))
        case .interfaceHasInvalidPrivateKey:
            return (tr("macAlertPrivateKeyInvalid"), tr("alertInvalidInterfaceMessagePrivateKeyInvalid"))
        case .interfaceHasInvalidListenPort(let value):
            return (tr(format: "macAlertListenPortInvalid (%@)", value), tr("alertInvalidInterfaceMessageListenPortInvalid"))
        case .interfaceHasInvalidAddress(let value):
            return (tr(format: "macAlertAddressInvalid (%@)", value), tr("alertInvalidInterfaceMessageAddressInvalid"))
        case .interfaceHasInvalidDNS(let value):
            return (tr(format: "macAlertDNSInvalid (%@)", value), tr("alertInvalidInterfaceMessageDNSInvalid"))
        case .interfaceHasInvalidMTU(let value):
            return (tr(format: "macAlertMTUInvalid (%@)", value), tr("alertInvalidInterfaceMessageMTUInvalid"))
        case .interfaceHasUnrecognizedKey(let value):
            return (tr(format: "macAlertUnrecognizedInterfaceKey (%@)", value), tr("macAlertInfoUnrecognizedInterfaceKey"))
        case .peerHasNoPublicKey:
            return (tr("alertInvalidPeerMessagePublicKeyRequired"), tr("alertInvalidPeerMessagePublicKeyInvalid"))
        case .peerHasInvalidPublicKey:
            return (tr("macAlertPublicKeyInvalid"), tr("alertInvalidPeerMessagePublicKeyInvalid"))
        case .peerHasInvalidPreSharedKey:
            return (tr("macAlertPreSharedKeyInvalid"), tr("alertInvalidPeerMessagePreSharedKeyInvalid"))
        case .peerHasInvalidAllowedIP(let value):
            return (tr(format: "macAlertAllowedIPInvalid (%@)", value), tr("alertInvalidPeerMessageAllowedIPsInvalid"))
        case .peerHasInvalidEndpoint(let value):
            return (tr(format: "macAlertEndpointInvalid (%@)", value), tr("alertInvalidPeerMessageEndpointInvalid"))
        case .peerHasInvalidPersistentKeepAlive(let value):
            return (tr(format: "macAlertPersistentKeepliveInvalid (%@)", value), tr("alertInvalidPeerMessagePersistentKeepaliveInvalid"))
        case .peerHasUnrecognizedKey(let value):
            return (tr(format: "macAlertUnrecognizedPeerKey (%@)", value), tr("macAlertInfoUnrecognizedPeerKey"))
        case .peerHasInvalidTransferBytes(let line):
            return (tr(format: "macAlertInvalidLine (%@)", String(line)), "")
        case .peerHasInvalidLastHandshakeTime(let line):
            return (tr(format: "macAlertInvalidLine (%@)", String(line)), "")
        case .multiplePeersWithSamePublicKey:
            return (tr("alertInvalidPeerMessagePublicKeyDuplicated"), "")
        case .multipleEntriesForKey(let value):
            return (tr(format: "macAlertMultipleEntriesForKey (%@)", value), "")
        }
    }
}
