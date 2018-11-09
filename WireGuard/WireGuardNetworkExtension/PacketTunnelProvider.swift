// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

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

    // MARK: NEPacketTunnelProvider

    /// Begin the process of establishing the tunnel.
    override func startTunnel(options: [String: NSObject]?,
                              completionHandler startTunnelCompletionHandler: @escaping (Error?) -> Void) {

        guard let tunnelProviderProtocol = self.protocolConfiguration as? NETunnelProviderProtocol,
            let tunnelConfiguration = tunnelProviderProtocol.tunnelConfiguration() else {
                ErrorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid, from: self)
                startTunnelCompletionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
                return
        }

        startTunnel(with: tunnelConfiguration, completionHandler: startTunnelCompletionHandler)
    }

    func startTunnel(with tunnelConfiguration: TunnelConfiguration, completionHandler startTunnelCompletionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel", log: OSLog.default, type: .info)

        // Resolve endpoint domains

        let endpoints = tunnelConfiguration.peers.map { $0.endpoint }
        var resolvedEndpoints: [Endpoint?] = []
        do {
            resolvedEndpoints = try DNSResolver.resolveSync(endpoints: endpoints)
        } catch DNSResolverError.dnsResolutionFailed(let hostnames) {
            os_log("Starting tunnel failed: DNS resolution failure for %{public}d hostnames (%{public}s)", log: OSLog.default,
                   type: .error, hostnames.count, hostnames.joined(separator: ", "))
            ErrorNotifier.notify(PacketTunnelProviderError.dnsResolutionFailure(hostnames: hostnames), from: self)
            startTunnelCompletionHandler(PacketTunnelProviderError.dnsResolutionFailure(hostnames: hostnames))
            return
        } catch {
            // There can be no other errors from DNSResolver.resolveSync()
            fatalError()
        }
        assert(endpoints.count == resolvedEndpoints.count)

        // Setup packetTunnelSettingsGenerator

        let packetTunnelSettingsGenerator = PacketTunnelSettingsGenerator(tunnelConfiguration: tunnelConfiguration,
                                                                          resolvedEndpoints: resolvedEndpoints)

        // Bring up wireguard-go backend

        configureLogger()

        let fd = packetFlow.value(forKeyPath: "socket.fileDescriptor") as! Int32
        if fd < 0 {
            os_log("Starting tunnel failed: Could not determine file descriptor", log: OSLog.default, type: .error)
            ErrorNotifier.notify(PacketTunnelProviderError.couldNotStartWireGuard, from: self)
            startTunnelCompletionHandler(PacketTunnelProviderError.couldNotStartWireGuard)
            return
        }

        let wireguardSettings = packetTunnelSettingsGenerator.generateWireGuardSettings()
        let handle = connect(interfaceName: tunnelConfiguration.interface.name, settings: wireguardSettings, fd: fd)

        if handle < 0 {
            os_log("Starting tunnel failed: Could not start WireGuard", log: OSLog.default, type: .error)
            ErrorNotifier.notify(PacketTunnelProviderError.couldNotStartWireGuard, from: self)
            startTunnelCompletionHandler(PacketTunnelProviderError.couldNotStartWireGuard)
            return
        }

        wgHandle = handle

        // Apply network settings

        let networkSettings: NEPacketTunnelNetworkSettings = packetTunnelSettingsGenerator.generateNetworkSettings()
        setTunnelNetworkSettings(networkSettings) { (error) in
            if let error = error {
                os_log("Starting tunnel failed: Error setting network settings: %s", log: OSLog.default, type: .error, error.localizedDescription)
                ErrorNotifier.notify(PacketTunnelProviderError.coultNotSetNetworkSettings, from: self)
                startTunnelCompletionHandler(PacketTunnelProviderError.coultNotSetNetworkSettings)
            } else {
                startTunnelCompletionHandler(nil /* No errors */)
            }
        }
    }

    /// Begin the process of stopping the tunnel.
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping tunnel", log: OSLog.default, type: .info)
        if let handle = wgHandle {
            wgTurnOff(handle)
        }
        completionHandler()
    }

    private func configureLogger() {
        wgSetLogger { (level, msgCStr) in
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
            let msg = (msgCStr != nil) ? String(cString: msgCStr!) : ""
            os_log("%{public}s", log: OSLog.default, type: logType, msg)
        }
    }

    private func connect(interfaceName: String, settings: String, fd: Int32) -> Int32 { // swiftlint:disable:this cyclomatic_complexity
        return withStringsAsGoStrings(interfaceName, settings) { (nameGoStr, settingsGoStr) -> Int32 in
            return wgTurnOn(nameGoStr, settingsGoStr, fd)
        }
    }
}

private func withStringsAsGoStrings<R>(_ str1: String, _ str2: String, closure: (gostring_t, gostring_t) -> R) -> R {
    return str1.withCString { (s1cStr) -> R in
        let gstr1 = gostring_t(p: s1cStr, n: str1.utf8.count)
        return str2.withCString { (s2cStr) -> R in
            let gstr2 = gostring_t(p: s2cStr, n: str2.utf8.count)
            return closure(gstr1, gstr2)
        }
    }
}
