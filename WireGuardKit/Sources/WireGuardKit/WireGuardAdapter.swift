// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

import Foundation
import NetworkExtension
import libwg_go

public enum WireGuardAdapterError: Error {
    /// Failure to locate socket descriptor.
    case cannotLocateSocketDescriptor

    /// Failure to perform an operation in such state
    case invalidState

    /// Failure to resolve endpoints
    case dnsResolution([DNSResolutionError])

    /// Failure to set network settings
    case setNetworkSettings(Error)

    /// Timeout when calling to set network settings
    case setNetworkSettingsTimeout

    /// Failure to start WireGuard backend
    case startWireGuardBackend(Int32)
}

public class WireGuardAdapter {
    public typealias LogHandler = (WireGuardLogLevel, String) -> Void

    /// Network routes monitor.
    private var networkMonitor: NWPathMonitor?

    /// Packet tunnel provider.
    private weak var packetTunnelProvider: NEPacketTunnelProvider?

    /// Log handler closure.
    private var logHandler: LogHandler?

    /// WireGuard internal handle returned by `wgTurnOn` that's used to associate the calls
    /// with the specific WireGuard tunnel.
    private var wireguardHandle: Int32?

    /// Private queue used to synchronize access to `WireGuardAdapter` members.
    private let workQueue = DispatchQueue(label: "WireGuardAdapterWorkQueue")

    /// Flag that tells if the adapter has already started.
    private var isStarted = false

    /// Packet tunnel settings generator.
    private var settingsGenerator: PacketTunnelSettingsGenerator?

    /// Tunnel device file descriptor.
    private var tunnelFileDescriptor: Int32? {
        return self.packetTunnelProvider?.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32
    }

    /// Returns a Wireguard version.
    class var version: String {
        return String(cString: wgVersion())
    }

    /// Returns the tunnel device interface name, or nil on error.
    /// - Returns: String.
    public var interfaceName: String? {
        guard let tunnelFileDescriptor = self.tunnelFileDescriptor else { return nil }

        var buffer = [UInt8](repeating: 0, count: Int(IFNAMSIZ))

        return buffer.withUnsafeMutableBufferPointer { (mutableBufferPointer) in
            guard let baseAddress = mutableBufferPointer.baseAddress else { return nil }

            var ifnameSize = socklen_t(IFNAMSIZ)
            let result = getsockopt(
                tunnelFileDescriptor,
                2 /* SYSPROTO_CONTROL */,
                2 /* UTUN_OPT_IFNAME */,
                baseAddress,
                &ifnameSize)

            if result == 0 {
                return String(cString: baseAddress)
            } else {
                return nil
            }
        }
    }

    // MARK: - Initialization

    /// Designated initializer.
    /// - Parameter packetTunnelProvider: an instance of `NEPacketTunnelProvider`. Internally stored
    ///   as a weak reference.
    public init(with packetTunnelProvider: NEPacketTunnelProvider) {
        self.packetTunnelProvider = packetTunnelProvider
    }

    deinit {
        // Force deactivate logger to make sure that no further calls to the instance of this class
        // can happen after deallocation.
        deactivateLogHandler()

        // Cancel network monitor
        networkMonitor?.cancel()

        // Shutdown the tunnel
        if let handle = self.wireguardHandle {
            wgTurnOff(handle)
        }
    }

    // MARK: - Public methods

    /// Returns a runtime configuration from WireGuard.
    /// - Parameter completionHandler: completion handler.
    public func getRuntimeConfiguration(completionHandler: @escaping (String?) -> Void) {
        workQueue.async {
            guard let handle = self.wireguardHandle else {
                completionHandler(nil)
                return
            }

            if let settings = wgGetConfig(handle) {
                completionHandler(String(cString: settings))
                free(settings)
            } else {
                completionHandler(nil)
            }
        }
    }

    /// Set log handler.
    /// - Parameter logHandler: log handler closure
    public func setLogHandler(_ logHandler: LogHandler?) {
        workQueue.async {
            self.logHandler = logHandler
        }

        if logHandler == nil {
            deactivateLogHandler()
        } else {
            activateLogHandler()
        }
    }

    /// Start the tunnel tunnel.
    /// - Parameters:
    ///   - tunnelConfiguration: tunnel configuration.
    ///   - completionHandler: completion handler.
    public func start(tunnelConfiguration: TunnelConfiguration, completionHandler: @escaping (WireGuardAdapterError?) -> Void) {
        workQueue.async {
            guard !self.isStarted else {
                completionHandler(.invalidState)
                return
            }

            guard let tunnelFileDescriptor = self.tunnelFileDescriptor else {
                completionHandler(.cannotLocateSocketDescriptor)
                return
            }

            #if os(macOS)
            wgEnableRoaming(true)
            #endif

            let networkMonitor = NWPathMonitor()
            networkMonitor.pathUpdateHandler = { [weak self] path in
                self?.didReceivePathUpdate(path: path)
            }

            networkMonitor.start(queue: self.workQueue)
            self.networkMonitor = networkMonitor

            self.updateNetworkSettings(tunnelConfiguration: tunnelConfiguration) { (settingsGenerator, error) in
                if let error = error {
                    completionHandler(error)
                } else {
                    var returnError: WireGuardAdapterError?
                    let handle = wgTurnOn(settingsGenerator!.uapiConfiguration(), tunnelFileDescriptor)

                    if handle >= 0 {
                        self.wireguardHandle = handle
                        self.isStarted = true
                    } else {
                        returnError = .startWireGuardBackend(handle)
                    }

                    completionHandler(returnError)
                }
            }
        }
    }

    /// Stop the tunnel.
    /// - Parameter completionHandler: completion handler.
    public func stop(completionHandler: @escaping (WireGuardAdapterError?) -> Void) {
        workQueue.async {
            guard self.isStarted else {
                completionHandler(.invalidState)
                return
            }

            self.networkMonitor?.cancel()
            self.networkMonitor = nil

            if let handle = self.wireguardHandle {
                wgTurnOff(handle)
                self.wireguardHandle = nil
            }

            self.isStarted = false

            completionHandler(nil)
        }
    }

    /// Update runtime configuration.
    /// - Parameters:
    ///   - tunnelConfiguration: tunnel configuration.
    ///   - completionHandler: completion handler.
    public func update(tunnelConfiguration: TunnelConfiguration, completionHandler: @escaping (WireGuardAdapterError?) -> Void) {
        workQueue.async {
            guard self.isStarted else {
                completionHandler(.invalidState)
                return
            }

            // Tell the system that the tunnel is going to reconnect using new WireGuard
            // configuration.
            // This will broadcast the `NEVPNStatusDidChange` notification to the GUI process.
            self.packetTunnelProvider?.reasserting = true

            self.updateNetworkSettings(tunnelConfiguration: tunnelConfiguration) { (settingsGenerator, error) in
                if let error = error {
                    completionHandler(error)
                } else {
                    if let handle = self.wireguardHandle {
                        wgSetConfig(handle, settingsGenerator!.uapiConfiguration())
                    }
                    completionHandler(nil)
                }

                self.packetTunnelProvider?.reasserting = false
            }
        }
    }

    // MARK: - Private methods

    /// Install WireGuard log handler.
    private func activateLogHandler() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        wgSetLogger(context) { (context, logLevel, message) in
            guard let context = context, let message = message else { return }

            let unretainedSelf = Unmanaged<WireGuardAdapter>.fromOpaque(context)
                .takeUnretainedValue()

            let swiftString = String(cString: message).trimmingCharacters(in: .newlines)
            let tunnelLogLevel = WireGuardLogLevel(rawValue: logLevel) ?? .debug

            unretainedSelf.handleLogLine(level: tunnelLogLevel, message: swiftString)
        }
    }

    /// Uninstall WireGuard log handler.
    private func deactivateLogHandler() {
        wgSetLogger(nil, nil)
    }

    /// Resolve endpoints and update network configuration.
    /// - Parameters:
    ///   - tunnelConfiguration: tunnel configuration
    ///   - completionHandler: completion handler
    private func updateNetworkSettings(tunnelConfiguration: TunnelConfiguration, completionHandler: @escaping (PacketTunnelSettingsGenerator?, WireGuardAdapterError?) -> Void) {
        let resolvedEndpoints: [Endpoint?]

        let resolvePeersResult = Result { try self.resolvePeers(for: tunnelConfiguration) }
            .mapError { $0 as! WireGuardAdapterError }

        switch resolvePeersResult {
        case .success(let endpoints):
            resolvedEndpoints = endpoints
        case .failure(let error):
            completionHandler(nil, error)
            return
        }

        let settingsGenerator = PacketTunnelSettingsGenerator(tunnelConfiguration: tunnelConfiguration, resolvedEndpoints: resolvedEndpoints)
        let networkSettings = settingsGenerator.generateNetworkSettings()
        self.settingsGenerator = settingsGenerator

        var systemError: Error?
        let condition = NSCondition()

        // Activate the condition
        condition.lock()
        defer { condition.unlock() }

        self.packetTunnelProvider?.setTunnelNetworkSettings(networkSettings, completionHandler: { (error) in
            systemError = error
            condition.signal()
        })

        // Packet tunnel's `setTunnelNetworkSettings` times out in certain
        // scenarios & never calls the given callback.
        let setTunnelNetworkSettingsTimeout: TimeInterval = 5 // seconds

        if condition.wait(until: Date().addingTimeInterval(setTunnelNetworkSettingsTimeout)) {
            let returnError = systemError.map { WireGuardAdapterError.setNetworkSettings($0) }

            completionHandler(settingsGenerator, returnError)
        } else {
            completionHandler(nil, .setNetworkSettingsTimeout)
        }
    }

    /// Resolve peers of the given tunnel configuration.
    /// - Parameter tunnelConfiguration: tunnel configuration.
    /// - Throws: an error of type `WireGuardAdapterError`.
    /// - Returns: The list of resolved endpoints.
    private func resolvePeers(for tunnelConfiguration: TunnelConfiguration) throws -> [Endpoint?] {
        let endpoints = tunnelConfiguration.peers.map { $0.endpoint }
        let resolutionResults = DNSResolver.resolveSync(endpoints: endpoints)
        let resolutionErrors = resolutionResults.compactMap { (result) -> DNSResolutionError? in
            if case .failure(let error) = result {
                return error
            } else {
                return nil
            }
        }
        assert(endpoints.count == resolutionResults.count)
        guard resolutionErrors.isEmpty else {
            throw WireGuardAdapterError.dnsResolution(resolutionErrors)
        }

        let resolvedEndpoints = resolutionResults.map { (result) -> Endpoint? in
            return try? result?.get()
        }

        return resolvedEndpoints
    }

    /// Private helper to pass the logs coming from WireGuard to
    /// - Parameters:
    ///   - level: log level
    ///   - message: message
    private func handleLogLine(level: WireGuardLogLevel, message: String) {
        workQueue.async {
            self.logHandler?(level, message)
        }
    }

    /// Helper method used by network path monitor.
    /// - Parameter path: new network path
    private func didReceivePathUpdate(path: Network.NWPath) {
        guard self.isStarted else { return }

        if let handle = self.wireguardHandle {
            self.handleLogLine(level: .debug, message: "Network change detected with \(path.status) route and interface order \(path.availableInterfaces)")

            #if os(iOS)
            if let settingsGenerator = self.settingsGenerator {
                wgSetConfig(handle, settingsGenerator.endpointUapiConfiguration())
            }

            // TODO: dynamically turn on or off WireGuard backend when entering airplane mode
            #endif

            wgBumpSockets(handle)
        }
    }
}

/// A enum describing Wireguard log levels defined in `api-ios.go` from `wireguard-apple`
/// repository.
public enum WireGuardLogLevel: Int32 {
    case debug = 0
    case info = 1
    case error = 2
}
