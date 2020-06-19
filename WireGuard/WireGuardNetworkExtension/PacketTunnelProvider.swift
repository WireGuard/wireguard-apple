// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation
import Network
import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var handle: Int32?
    private var networkMonitor: NWPathMonitor?
    private var ifname: String?
    private var packetTunnelSettingsGenerator: PacketTunnelSettingsGenerator?

    deinit {
        networkMonitor?.cancel()
    }

    override func startTunnel(options: [String: NSObject]?, completionHandler startTunnelCompletionHandler: @escaping (Error?) -> Void) {
        let activationAttemptId = options?["activationAttemptId"] as? String
        let errorNotifier = ErrorNotifier(activationAttemptId: activationAttemptId)

        guard let tunnelProviderProtocol = protocolConfiguration as? NETunnelProviderProtocol,
            let tunnelConfiguration = tunnelProviderProtocol.asTunnelConfiguration() else {
                errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
                startTunnelCompletionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
                return
        }

        configureLogger()
        #if os(macOS)
        wgEnableRoaming(true)
        #endif

        wg_log(.info, message: "Starting tunnel from the " + (activationAttemptId == nil ? "OS directly, rather than the app" : "app"))

        let endpoints = tunnelConfiguration.peers.map { $0.endpoint }
        guard let resolvedEndpoints = DNSResolver.resolveSync(endpoints: endpoints) else {
            errorNotifier.notify(PacketTunnelProviderError.dnsResolutionFailure)
            startTunnelCompletionHandler(PacketTunnelProviderError.dnsResolutionFailure)
            return
        }
        assert(endpoints.count == resolvedEndpoints.count)

        packetTunnelSettingsGenerator = PacketTunnelSettingsGenerator(tunnelConfiguration: tunnelConfiguration, resolvedEndpoints: resolvedEndpoints)

        setTunnelNetworkSettings(packetTunnelSettingsGenerator!.generateNetworkSettings()) { error in
            if let error = error {
                wg_log(.error, message: "Starting tunnel failed with setTunnelNetworkSettings returning \(error.localizedDescription)")
                errorNotifier.notify(PacketTunnelProviderError.couldNotSetNetworkSettings)
                startTunnelCompletionHandler(PacketTunnelProviderError.couldNotSetNetworkSettings)
            } else {
                self.networkMonitor = NWPathMonitor()
                self.networkMonitor!.pathUpdateHandler = self.pathUpdate
                self.networkMonitor!.start(queue: DispatchQueue(label: "NetworkMonitor"))

                let fileDescriptor = (self.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32) ?? -1
                if fileDescriptor < 0 {
                    wg_log(.error, staticMessage: "Starting tunnel failed: Could not determine file descriptor")
                    errorNotifier.notify(PacketTunnelProviderError.couldNotDetermineFileDescriptor)
                    startTunnelCompletionHandler(PacketTunnelProviderError.couldNotDetermineFileDescriptor)
                    return
                }

                self.ifname = Self.getInterfaceName(fileDescriptor: fileDescriptor)
                wg_log(.info, message: "Tunnel interface is \(self.ifname ?? "unknown")")

                let handle = self.packetTunnelSettingsGenerator!.uapiConfiguration()
                    .withCString { return wgTurnOn($0, fileDescriptor) }
                if handle < 0 {
                    wg_log(.error, message: "Starting tunnel failed with wgTurnOn returning \(handle)")
                    errorNotifier.notify(PacketTunnelProviderError.couldNotStartBackend)
                    startTunnelCompletionHandler(PacketTunnelProviderError.couldNotStartBackend)
                    return
                }
                self.handle = handle
                startTunnelCompletionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        networkMonitor?.cancel()
        networkMonitor = nil

        ErrorNotifier.removeLastErrorFile()

        wg_log(.info, staticMessage: "Stopping tunnel")
        if let handle = handle {
            wgTurnOff(handle)
        }
        completionHandler()

        #if os(macOS)
        // HACK: This is a filthy hack to work around Apple bug 32073323 (dup'd by us as 47526107).
        // Remove it when they finally fix this upstream and the fix has been rolled out to
        // sufficient quantities of users.
        exit(0)
        #endif
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let completionHandler = completionHandler else { return }
        guard let handle = handle else {
            completionHandler(nil)
            return
        }
        if messageData.count == 1 && messageData[0] == 0 {
            guard let settings = wgGetConfig(handle) else {
                completionHandler(nil)
                return
            }
            completionHandler(String(cString: settings).data(using: .utf8)!)
            free(settings)
        } else {
            completionHandler(nil)
        }
    }

    private class func getInterfaceName(fileDescriptor: Int32) -> String? {
        var ifnameBytes = [CChar](repeating: 0, count: Int(IF_NAMESIZE))

        return ifnameBytes.withUnsafeMutableBufferPointer { bufferPointer -> String? in
            guard let baseAddress = bufferPointer.baseAddress else { return nil }

            var ifnameSize = socklen_t(bufferPointer.count)
            let result = getsockopt(
                fileDescriptor,
                2 /* SYSPROTO_CONTROL */,
                2 /* UTUN_OPT_IFNAME */,
                baseAddress, &ifnameSize
            )

            if result == 0 {
                return String(cString: baseAddress)
            } else {
                return nil
            }
        }
    }

    private func configureLogger() {
        Logger.configureGlobal(tagged: "NET", withFilePath: FileManager.logFileURL?.path)
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

    private func pathUpdate(path: Network.NWPath) {
        guard let handle = handle else { return }
        wg_log(.debug, message: "Network change detected with \(path.status) route and interface order \(path.availableInterfaces)")

        #if os(iOS)
        if let packetTunnelSettingsGenerator = packetTunnelSettingsGenerator {
            _ = packetTunnelSettingsGenerator.endpointUapiConfiguration()
                .withCString { return wgSetConfig(handle, $0) }
        }
        #endif
        wgBumpSockets(handle)
    }
}
