// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation
import NetworkExtension
import os

class PacketTunnelProvider: NEPacketTunnelProvider {

    #if os(macOS)
    // Number of tunnels starting or started in this process, used to ensure
    // the exit(0) hack in stopTunnel() doesn't tear down other tunnels in
    // case the OS runs multiple simultaneous tunnels in a single extension
    // process. Tunnels are counted for the entire duration of the start
    // attempt, so that another tunnel stopping meanwhile doesn't consider
    // itself the last one in the process.
    private static var startedTunnelCount = 0
    private static let startedTunnelCountLock = NSLock()
    private var hasStartedTunnel = false

    private func registerStartedTunnel() {
        PacketTunnelProvider.startedTunnelCountLock.lock()
        PacketTunnelProvider.startedTunnelCount += 1
        hasStartedTunnel = true
        PacketTunnelProvider.startedTunnelCountLock.unlock()
    }

    // Returns true if this was the last starting or started tunnel in the
    // process, i.e. the process is free to exit.
    @discardableResult
    private func unregisterStartedTunnel() -> Bool {
        PacketTunnelProvider.startedTunnelCountLock.lock()
        defer { PacketTunnelProvider.startedTunnelCountLock.unlock() }
        if hasStartedTunnel {
            hasStartedTunnel = false
            PacketTunnelProvider.startedTunnelCount -= 1
        }
        return PacketTunnelProvider.startedTunnelCount == 0
    }
    #endif

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { logLevel, message in
            wg_log(logLevel.osLogLevel, message: message)
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let activationAttemptId = options?["activationAttemptId"] as? String
        let errorNotifier = ErrorNotifier(activationAttemptId: activationAttemptId)

        Logger.configureGlobal(tagged: "NET", withFilePath: FileManager.logFileURL?.path)

        wg_log(.info, message: "Starting tunnel from the " + (activationAttemptId == nil ? "OS directly, rather than the app" : "app"))

        #if os(macOS)
        registerStartedTunnel()
        #endif

        guard let tunnelProviderProtocol = self.protocolConfiguration as? NETunnelProviderProtocol,
              let tunnelConfiguration = tunnelProviderProtocol.asTunnelConfiguration() else {
            errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            #if os(macOS)
            unregisterStartedTunnel()
            #endif
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            return
        }

        // Start the tunnel
        adapter.start(tunnelConfiguration: tunnelConfiguration, isSplitDNSEnabled: tunnelProviderProtocol.isSplitDNSEnabled) { adapterError in
            guard let adapterError = adapterError else {
                let interfaceName = self.adapter.interfaceName ?? "unknown"

                wg_log(.info, message: "Tunnel interface is \(interfaceName)")

                completionHandler(nil)
                return
            }

            #if os(macOS)
            self.unregisterStartedTunnel()
            #endif

            switch adapterError {
            case .cannotLocateTunnelFileDescriptor:
                wg_log(.error, staticMessage: "Starting tunnel failed: could not determine file descriptor")
                errorNotifier.notify(PacketTunnelProviderError.couldNotDetermineFileDescriptor)
                completionHandler(PacketTunnelProviderError.couldNotDetermineFileDescriptor)

            case .dnsResolution(let dnsErrors):
                let hostnamesWithDnsResolutionFailure = dnsErrors.map { $0.address }
                    .joined(separator: ", ")
                wg_log(.error, message: "DNS resolution failed for the following hostnames: \(hostnamesWithDnsResolutionFailure)")
                errorNotifier.notify(PacketTunnelProviderError.dnsResolutionFailure)
                completionHandler(PacketTunnelProviderError.dnsResolutionFailure)

            case .setNetworkSettings(let error):
                wg_log(.error, message: "Starting tunnel failed with setTunnelNetworkSettings returning \(error.localizedDescription)")
                errorNotifier.notify(PacketTunnelProviderError.couldNotSetNetworkSettings)
                completionHandler(PacketTunnelProviderError.couldNotSetNetworkSettings)

            case .startWireGuardBackend(let errorCode):
                wg_log(.error, message: "Starting tunnel failed with wgTurnOn returning \(errorCode)")
                errorNotifier.notify(PacketTunnelProviderError.couldNotStartBackend)
                completionHandler(PacketTunnelProviderError.couldNotStartBackend)

            case .invalidState:
                // Must never happen
                fatalError()
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        wg_log(.info, staticMessage: "Stopping tunnel")

        adapter.stop { error in
            ErrorNotifier.removeLastErrorFile()

            if let error = error {
                wg_log(.error, message: "Failed to stop WireGuard adapter: \(error.localizedDescription)")
            }
            completionHandler()

            #if os(macOS)
            // HACK: This is a filthy hack to work around Apple bug 32073323 (dup'd by us as 47526107).
            // Remove it when they finally fix this upstream and the fix has been rolled out to
            // sufficient quantities of users.
            // Since multiple tunnels may be active simultaneously, only exit
            // once the last starting or started tunnel in this process is
            // being stopped.
            if self.unregisterStartedTunnel() {
                exit(0)
            }
            #endif
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let completionHandler = completionHandler else { return }

        if messageData.count == 1 && messageData[0] == 0 {
            adapter.getRuntimeConfiguration { settings in
                var data: Data?
                if let settings = settings {
                    data = settings.data(using: .utf8)!
                }
                completionHandler(data)
            }
        } else {
            completionHandler(nil)
        }
    }
}

extension WireGuardLogLevel {
    var osLogLevel: OSLogType {
        switch self {
        case .verbose:
            return .debug
        case .error:
            return .error
        }
    }
}
