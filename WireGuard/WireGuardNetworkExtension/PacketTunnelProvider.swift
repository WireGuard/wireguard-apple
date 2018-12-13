// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation
import Network
import NetworkExtension
import os.log

enum PacketTunnelProviderError: Error {
    case savedProtocolConfigurationIsInvalid
    case dnsResolutionFailure(hostnames: [String])
    case couldNotStartWireGuard
    case coultNotSetNetworkSettings
}

/// A packet tunnel provider object.
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: Properties

    private var wgHandle: Int32?

    private var networkMonitor: NWPathMonitor?

    // MARK: NEPacketTunnelProvider

    deinit {
        networkMonitor?.cancel()
    }

    /// Begin the process of establishing the tunnel.
    override func startTunnel(options: [String: NSObject]?, completionHandler startTunnelCompletionHandler: @escaping (Error?) -> Void) {

        guard let tunnelProviderProtocol = self.protocolConfiguration as? NETunnelProviderProtocol,
            let tunnelConfiguration = tunnelProviderProtocol.tunnelConfiguration() else {
                ErrorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid, from: self)
                startTunnelCompletionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
                return
        }

        startTunnel(with: tunnelConfiguration, completionHandler: startTunnelCompletionHandler)
    }

    func startTunnel(with tunnelConfiguration: TunnelConfiguration, completionHandler startTunnelCompletionHandler: @escaping (Error?) -> Void) {

        configureLogger()

        wg_log(.info, message: "Starting tunnel '\(tunnelConfiguration.interface.name)'")

        let endpoints = tunnelConfiguration.peers.map { $0.endpoint }
        var resolvedEndpoints = [Endpoint?]()
        do {
            resolvedEndpoints = try DNSResolver.resolveSync(endpoints: endpoints)
        } catch DNSResolverError.dnsResolutionFailed(let hostnames) {
            wg_log(.error, staticMessage: "Starting tunnel failed: DNS resolution failure")
            wg_log(.error, message: "Hostnames for which DNS resolution failed: \(hostnames.joined(separator: ", "))")
            ErrorNotifier.notify(PacketTunnelProviderError.dnsResolutionFailure(hostnames: hostnames), from: self)
            startTunnelCompletionHandler(PacketTunnelProviderError.dnsResolutionFailure(hostnames: hostnames))
            return
        } catch {
            // There can be no other errors from DNSResolver.resolveSync()
            fatalError()
        }
        assert(endpoints.count == resolvedEndpoints.count)

        // Setup packetTunnelSettingsGenerator

        let packetTunnelSettingsGenerator = PacketTunnelSettingsGenerator(tunnelConfiguration: tunnelConfiguration, resolvedEndpoints: resolvedEndpoints)

        // Bring up wireguard-go backend

        let fileDescriptor = packetFlow.value(forKeyPath: "socket.fileDescriptor") as! Int32 //swiftlint:disable:this force_cast
        if fileDescriptor < 0 {
            wg_log(.error, staticMessage: "Starting tunnel failed: Could not determine file descriptor")
            ErrorNotifier.notify(PacketTunnelProviderError.couldNotStartWireGuard, from: self)
            startTunnelCompletionHandler(PacketTunnelProviderError.couldNotStartWireGuard)
            return
        }

        let wireguardSettings = packetTunnelSettingsGenerator.uapiConfiguration()

        var handle: Int32 = -1

        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { path in
            guard handle >= 0 else { return }
            if path.status == .satisfied {
                wg_log(.debug, message: "Network change detected, re-establishing sockets and IPs: \(path.availableInterfaces)")
                let endpointString = packetTunnelSettingsGenerator.endpointUapiConfiguration(currentListenPort: wgGetListenPort(handle))
                let err = endpointString.withCString {
                    wgSetConfig(handle, gostring_t(p: $0, n: endpointString.utf8.count))
                }
                if err == -EADDRINUSE {
                    let endpointString = packetTunnelSettingsGenerator.endpointUapiConfiguration(currentListenPort: 0)
                    _ = endpointString.withCString {
                        wgSetConfig(handle, gostring_t(p: $0, n: endpointString.utf8.count))
                    }
                }
            }
        }
        networkMonitor?.start(queue: DispatchQueue(label: "NetworkMonitor"))

        handle = connect(interfaceName: tunnelConfiguration.interface.name, settings: wireguardSettings, fileDescriptor: fileDescriptor)

        if handle < 0 {
            wg_log(.error, staticMessage: "Starting tunnel failed: Could not start WireGuard")
            ErrorNotifier.notify(PacketTunnelProviderError.couldNotStartWireGuard, from: self)
            startTunnelCompletionHandler(PacketTunnelProviderError.couldNotStartWireGuard)
            return
        }

        wgHandle = handle

        // Apply network settings

        let networkSettings: NEPacketTunnelNetworkSettings = packetTunnelSettingsGenerator.generateNetworkSettings()
        setTunnelNetworkSettings(networkSettings) { error in
            if let error = error {
                wg_log(.error, staticMessage: "Starting tunnel failed: Error setting network settings.")
                wg_log(.error, message: "Error from setTunnelNetworkSettings: \(error.localizedDescription)")
                ErrorNotifier.notify(PacketTunnelProviderError.coultNotSetNetworkSettings, from: self)
                startTunnelCompletionHandler(PacketTunnelProviderError.coultNotSetNetworkSettings)
            } else {
                startTunnelCompletionHandler(nil /* No errors */)
            }
        }
    }

    /// Begin the process of stopping the tunnel.
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        networkMonitor?.cancel()
        networkMonitor = nil

        wg_log(.info, staticMessage: "Stopping tunnel")
        if let handle = wgHandle {
            wgTurnOff(handle)
        }
        completionHandler()
    }

    private func configureLogger() {
        Logger.configureGlobal(withFilePath: FileManager.networkExtensionLogFileURL?.path, withTag: "EXT")
        wgSetLogger { level, msgC in
            guard let msgC = msgC else { return }
            let logType: OSLogType
            switch level {
            case 0:
                logType = .debug
            case 1:
                logType = .info
            case 2:
                logType = .error
            default:
                logType = .default
            }
            wg_log(logType, message: String(cString: msgC))
        }
    }

    private func connect(interfaceName: String, settings: String, fileDescriptor: Int32) -> Int32 {
        return withStringsAsGoStrings(interfaceName, settings) { nameGoStr, settingsGoStr in
            return wgTurnOn(nameGoStr, settingsGoStr, fileDescriptor)
        }
    }
}

private func withStringsAsGoStrings<R>(_ str1: String, _ str2: String, closure: (gostring_t, gostring_t) -> R) -> R {
    return str1.withCString { s1cStr in
        let gstr1 = gostring_t(p: s1cStr, n: str1.utf8.count)
        return str2.withCString { s2cStr in
            let gstr2 = gostring_t(p: s2cStr, n: str2.utf8.count)
            return closure(gstr1, gstr2)
        }
    }
}
