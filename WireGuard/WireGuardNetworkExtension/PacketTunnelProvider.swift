// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

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
                var ifnameSize = socklen_t(IFNAMSIZ)
                let ifnamePtr = UnsafeMutablePointer<CChar>.allocate(capacity: Int(ifnameSize))
                ifnamePtr.initialize(repeating: 0, count: Int(ifnameSize))
                if getsockopt(fileDescriptor, 2 /* SYSPROTO_CONTROL */, 2 /* UTUN_OPT_IFNAME */, ifnamePtr, &ifnameSize) == 0 {
                    self.ifname = String(cString: ifnamePtr)
                }
                wg_log(.info, message: "Tunnel interface is \(self.ifname ?? "unknown")")
                let handle = self.packetTunnelSettingsGenerator!.uapiConfiguration().withGoString { return wgTurnOn($0, fileDescriptor) }
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
    }

    private func configureLogger() {
        Logger.configureGlobal(withFilePath: FileManager.networkExtensionLogFileURL?.path)
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
        guard let handle = handle, let packetTunnelSettingsGenerator = packetTunnelSettingsGenerator else { return }
        wg_log(.debug, message: "Network change detected with \(path.status) route and interface order \(path.availableInterfaces)")
        _ = packetTunnelSettingsGenerator.endpointUapiConfiguration().withGoString { return wgSetConfig(handle, $0) }
        var interfaces = path.availableInterfaces
        if let ifname = ifname {
            interfaces = interfaces.filter { $0.name != ifname }
        }
        if let ifscope = interfaces.first?.index {
            wgBindInterfaceScope(handle, Int32(ifscope))
        }
    }
}

extension String {
    func withGoString<R>(_ call: (gostring_t) -> R) -> R {
        func helper(_ pointer: UnsafePointer<Int8>?, _ call: (gostring_t) -> R) -> R {
            return call(gostring_t(p: pointer, n: utf8.count))
        }
        return helper(self, call)
    }
}
