// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import NetworkExtension
import Foundation
import os.log

enum PacketTunnelProviderError: Error {
    case savedProtocolConfigurationIsInvalid
    case dnsResolutionFailure(hostnames: [String])
    case couldNotStartWireGuard
    case coultNotSetNetworkSettings
}

private var logFileHandle: FileHandle?

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

        // Configure logging
        configureLogger()

        wg_log(.info, message: "WireGuard for iOS version \(appVersion())")
        wg_log(.info, message: "WireGuard Go backend version \(goBackendVersion())")
        wg_log(.info, message: "Tunnel interface name: \(tunnelConfiguration.interface.name)")

        wg_log(.info, staticMessage: "Starting tunnel")

        // Resolve endpoint domains

        let endpoints = tunnelConfiguration.peers.map { $0.endpoint }
        var resolvedEndpoints: [Endpoint?] = []
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

        let packetTunnelSettingsGenerator = PacketTunnelSettingsGenerator(tunnelConfiguration: tunnelConfiguration,
                                                                          resolvedEndpoints: resolvedEndpoints)

        // Bring up wireguard-go backend

        let fd = packetFlow.value(forKeyPath: "socket.fileDescriptor") as! Int32
        if fd < 0 {
            wg_log(.error, staticMessage: "Starting tunnel failed: Could not determine file descriptor")
            ErrorNotifier.notify(PacketTunnelProviderError.couldNotStartWireGuard, from: self)
            startTunnelCompletionHandler(PacketTunnelProviderError.couldNotStartWireGuard)
            return
        }

        let wireguardSettings = packetTunnelSettingsGenerator.generateWireGuardSettings()
        let handle = connect(interfaceName: tunnelConfiguration.interface.name, settings: wireguardSettings, fd: fd)

        if handle < 0 {
            wg_log(.error, staticMessage: "Starting tunnel failed: Could not start WireGuard")
            ErrorNotifier.notify(PacketTunnelProviderError.couldNotStartWireGuard, from: self)
            startTunnelCompletionHandler(PacketTunnelProviderError.couldNotStartWireGuard)
            return
        }

        wgHandle = handle

        // Apply network settings

        let networkSettings: NEPacketTunnelNetworkSettings = packetTunnelSettingsGenerator.generateNetworkSettings()
        setTunnelNetworkSettings(networkSettings) { (error) in
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
        wg_log(.info, staticMessage: "Stopping tunnel")
        if let handle = wgHandle {
            wgTurnOff(handle)
        }
        if let fileHandle = logFileHandle {
            fileHandle.closeFile()
        }
        completionHandler()
    }

    private func configureLogger() {

        // Setup writing the log to a file
        if let networkExtensionLogFileURL = FileManager.networkExtensionLogFileURL {
            let fileManager = FileManager.default
            let filePath = networkExtensionLogFileURL.path
            fileManager.createFile(atPath: filePath, contents: nil) // Create the file if it doesn't already exist
            if let fileHandle = FileHandle(forWritingAtPath: filePath) {
                logFileHandle = fileHandle
            } else {
                os_log("Can't open log file for writing. Log is not saved to file.", log: OSLog.default, type: .error)
                logFileHandle = nil
            }
        } else {
            os_log("Can't obtain log file URL. Log is not saved to file.", log: OSLog.default, type: .error)
        }

        // Setup WireGuard logger
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
            wg_log(logType, message: msg)
        }
    }

    private func connect(interfaceName: String, settings: String, fd: Int32) -> Int32 { // swiftlint:disable:this cyclomatic_complexity
        return withStringsAsGoStrings(interfaceName, settings) { (nameGoStr, settingsGoStr) -> Int32 in
            return wgTurnOn(nameGoStr, settingsGoStr, fd)
        }
    }

    func appVersion() -> String {
        var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
        if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion += " (\(appBuild))"
        }
        return appVersion
    }

    func goBackendVersion() -> String {
        return WIREGUARD_GO_VERSION
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

private func wg_log(_ type: OSLogType, staticMessage msg: StaticString) {
    // Write to os log
    os_log(msg, log: OSLog.default, type: type)
    // Write to file log
    let msgString: String = msg.withUTF8Buffer { (ptr: UnsafeBufferPointer<UInt8>) -> String in
        return String(decoding: ptr, as: UTF8.self)
    }
    file_log(type: type, message: msgString)
}

private func wg_log(_ type: OSLogType, message msg: String) {
    // Write to os log
    os_log("%{public}s", log: OSLog.default, type: type, msg)
    // Write to file log
    file_log(type: type, message: msg)
}

private func file_log(type: OSLogType, message: String) {
    var msgLine = type.toMessagePrefix() + message
    if (msgLine.last! != "\n") {
        msgLine.append("\n")
    }
    let data = msgLine.data(using: .utf8)
    if let data = data, let logFileHandle = logFileHandle {
        logFileHandle.write(data)
        logFileHandle.synchronizeFile()
    }
}

extension OSLogType {
    func toMessagePrefix() -> String {
        switch (self) {
            case .debug: return "Debug: "
            case .info: return "Info: "
            case .error: return "Error: "
            case .fault: return "Fault: "
        default:
            return "Unknown: "
        }
    }
}
