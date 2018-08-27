//
//  PacketTunnelProvider.swift
//  WireGuardNetworkExtension
//
//  Created by Jeroen Leenarts on 19-06-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import NetworkExtension
import os.log

enum PacketTunnelProviderError: Error {
    case tunnelSetupFailed
}

/// A packet tunnel provider object.
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: Properties

    var wgHandle: Int32?
    var wgContext: WireGuardContext?

    // MARK: NEPacketTunnelProvider

    /// Begin the process of establishing the tunnel.
    override func startTunnel(options: [String: NSObject]?, completionHandler startTunnelCompletionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel", log: Log.general, type: .info)

        let config = self.protocolConfiguration as! NETunnelProviderProtocol // swiftlint:disable:this force_cast
        let interfaceName = config.providerConfiguration![PCKeys.title.rawValue]! as! String // swiftlint:disable:this force_cast
        let mtu = config.providerConfiguration![PCKeys.mtu.rawValue] as? NSNumber
        let settings = config.providerConfiguration![PCKeys.settings.rawValue]! as! String // swiftlint:disable:this force_cast
        let endpoints = config.providerConfiguration?[PCKeys.endpoints.rawValue] as? String ?? ""
        let addresses = (config.providerConfiguration?[PCKeys.addresses.rawValue] as? String ?? "").commaSeparatedToArray()

        let validatedEndpoints = endpoints.commaSeparatedToArray().compactMap { try? Endpoint(endpointString: String($0)) }.compactMap {$0}
        let validatedAddresses = addresses.compactMap { try? CIDRAddress(stringRepresentation: String($0)) }.compactMap { $0 }

        guard let firstEndpoint = validatedEndpoints.first else {
            startTunnelCompletionHandler(PacketTunnelProviderError.tunnelSetupFailed)
            return

        }

        wgSetLogger { (level, tagCStr, msgCStr) in
            let tag = (tagCStr != nil) ? String(cString: tagCStr!) : ""
            let msg = (msgCStr != nil) ? String(cString: msgCStr!) : ""
            NSLog("wg log: \(level): \(tag): \(msg)")
        }

        wgContext = WireGuardContext(packetFlow: self.packetFlow)

        let handle = withStringsAsGoStrings(interfaceName, settings) { (nameGoStr, settingsGoStr) -> Int32 in
            return withUnsafeMutablePointer(to: &wgContext) { (wgCtxPtr) -> Int32 in
                return wgTurnOn(nameGoStr, settingsGoStr,
                                // read_fn: Read from the TUN interface and pass it on to WireGuard
                    { (wgCtxPtr, buf, len) -> Int in
                        guard let wgCtxPtr = wgCtxPtr else { return 0 }
                        guard let buf = buf else { return 0 }
                        let wgContext = wgCtxPtr.bindMemory(to: WireGuardContext.self, capacity: 1).pointee
                        var isTunnelClosed = false
                        guard let packet = wgContext.readPacket(isTunnelClosed: &isTunnelClosed) else { return 0 }
                        if isTunnelClosed { return -1 }
                        let packetData = packet.data
                        if packetData.count <= len {
                            packetData.copyBytes(to: buf, count: packetData.count)
                            return packetData.count
                        }
                        return 0
                },
                    // write_fn: Receive packets from WireGuard and write to the TUN interface
                    { (wgCtxPtr, buf, len) -> Int in
                        guard let wgCtxPtr = wgCtxPtr else { return 0 }
                        guard let buf = buf else { return 0 }
                        guard len > 0 else { return 0 }
                        let wgContext = wgCtxPtr.bindMemory(to: WireGuardContext.self, capacity: 1).pointee
                        let ipVersionBits = (buf[0] & 0xf0) >> 4
                        let ipVersion: sa_family_t? = {
                            if ipVersionBits == 4 { return sa_family_t(AF_INET) } // IPv4
                            if ipVersionBits == 6 { return sa_family_t(AF_INET6) } // IPv6
                            return nil
                        }()
                        guard let protocolFamily = ipVersion else { fatalError("Unknown IP version") }
                        let packet = NEPacket(data: Data(bytes: buf, count: len), protocolFamily: protocolFamily)
                        var isTunnelClosed = false
                        let isWritten = wgContext.writePacket(packet: packet, isTunnelClosed: &isTunnelClosed)
                        if isTunnelClosed { return -1 }
                        if isWritten {
                            return len
                        }
                        return 0
                },
                    wgCtxPtr)
            }
        }

        if handle < 0 {
            startTunnelCompletionHandler(PacketTunnelProviderError.tunnelSetupFailed)
            return
        }

        wgHandle = handle

        // We use the first endpoint for the ipAddress
        let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: firstEndpoint.ipAddress)
        newSettings.tunnelOverheadBytes = 80

        // IPv4 settings
        let validatedIPv4Addresses = validatedAddresses.filter { $0.addressType == .IPv4}
        if validatedIPv4Addresses.count > 0 {
            let ipv4Settings = NEIPv4Settings(addresses: validatedIPv4Addresses.map { $0.ipAddress }, subnetMasks: validatedIPv4Addresses.map { $0.subnetString })
            ipv4Settings.includedRoutes = [NEIPv4Route.default()]
            ipv4Settings.excludedRoutes = validatedEndpoints.filter { $0.addressType == .IPv4}.map {
                NEIPv4Route(destinationAddress: $0.ipAddress, subnetMask: "255.255.255.255")}

            newSettings.ipv4Settings = ipv4Settings
        }

        // IPv6 settings
        let validatedIPv6Addresses = validatedAddresses.filter { $0.addressType == .IPv6}
        if validatedIPv6Addresses.count > 0 {
            let ipv6Settings = NEIPv6Settings(addresses: validatedIPv6Addresses.map { $0.ipAddress }, networkPrefixLengths: validatedIPv6Addresses.map { NSNumber(value: $0.subnet) })
            ipv6Settings.includedRoutes = [NEIPv6Route.default()]
            ipv6Settings.excludedRoutes = validatedEndpoints.filter { $0.addressType == .IPv6}.map { NEIPv6Route(destinationAddress: $0.ipAddress, networkPrefixLength: 0)}

            newSettings.ipv6Settings = ipv6Settings
        }

        if let dns = config.providerConfiguration?[PCKeys.dns.rawValue] as? String {
            newSettings.dnsSettings = NEDNSSettings(servers: dns.commaSeparatedToArray())
        }
        if let mtu = mtu, mtu.intValue > 0 {
            newSettings.mtu = mtu
        }

        setTunnelNetworkSettings(newSettings) { (error) in
            if let error = error {
                NSLog("Error setting network settings: \(error)")
                startTunnelCompletionHandler(PacketTunnelProviderError.tunnelSetupFailed)
            } else {
                startTunnelCompletionHandler(nil /* No errors */)
            }
        }
    }

    /// Begin the process of stopping the tunnel.
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping tunnel", log: Log.general, type: .info)
        if let handle = wgHandle {
            wgTurnOff(handle)
        }
        wgContext?.closeTunnel()
        completionHandler()
    }

    /// Handle IPC messages from the app.
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let messageString = NSString(data: messageData, encoding: String.Encoding.utf8.rawValue) else {
            completionHandler?(nil)
            return
        }

        os_log("Got a message from the app: %s", log: Log.general, type: .info, messageString)

        let responseData = "Hello app".data(using: String.Encoding.utf8)
        completionHandler?(responseData)
    }
}

class WireGuardContext {
    private var packetFlow: NEPacketTunnelFlow
    private var outboundPackets: [NEPacket] = []
    private var isTunnelClosed: Bool = false
    private let readPacketCondition = NSCondition()

    init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }

    func closeTunnel() {
        isTunnelClosed = true
        readPacketCondition.signal()
    }

    func readPacket(isTunnelClosed: inout Bool) -> NEPacket? {
        if outboundPackets.isEmpty {
            let readPacketCondition = NSCondition()
            readPacketCondition.lock()
            var packetsObtained: [NEPacket]?
            packetFlow.readPacketObjects { (packets: [NEPacket]) in
                packetsObtained = packets
                readPacketCondition.signal()
            }
            // Wait till the completion handler of packetFlow.readPacketObjects() finishes
            while packetsObtained == nil && !self.isTunnelClosed {
                readPacketCondition.wait()
            }
            if let packetsObtained = packetsObtained {
                outboundPackets = packetsObtained
            }
            readPacketCondition.unlock()
        }
        isTunnelClosed = self.isTunnelClosed
        if outboundPackets.isEmpty {
            return nil
        } else {
            return outboundPackets.removeFirst()
        }
    }

    func writePacket(packet: NEPacket, isTunnelClosed: inout Bool) -> Bool {
        isTunnelClosed = self.isTunnelClosed
        return packetFlow.writePacketObjects([packet])
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
