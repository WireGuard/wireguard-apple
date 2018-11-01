//
//  Copyright © 2018 WireGuard LLC. All Rights Reserved.
//

import NetworkExtension
import os.log

enum PacketTunnelProviderError: Error {
    case invalidOptions
    case couldNotStartWireGuard
    case coultNotSetNetworkSettings
}

/// A packet tunnel provider object.
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: Properties

    private var wgHandle: Int32?
    private var wgContext: WireGuardContext?

    // MARK: NEPacketTunnelProvider

    /// Begin the process of establishing the tunnel.
    override func startTunnel(options: [String: NSObject]?,
                              completionHandler startTunnelCompletionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel", log: OSLog.default, type: .info)

        guard let options = options else {
            os_log("Starting tunnel failed: No options passed. Possible connection request from preferences.", log: OSLog.default, type: .error)
            // displayMessage is deprecated API
            displayMessage("Please use the WireGuard app to start up WireGuard VPN configurations.") { (_) in
                startTunnelCompletionHandler(PacketTunnelProviderError.invalidOptions)
            }
            return
        }

        guard let interfaceName = options[.interfaceName] as? String,
            let wireguardSettings = options[.wireguardSettings] as? String,
            let remoteAddress = options[.remoteAddress] as? String,
            let dnsServers = options[.dnsServers] as? [String],
            let mtu = options[.mtu] as? NSNumber,

            // IPv4 settings
            let ipv4Addresses = options[.ipv4Addresses] as? [String],
            let ipv4SubnetMasks = options[.ipv4SubnetMasks] as? [String],
            let ipv4IncludedRouteAddresses = options[.ipv4IncludedRouteAddresses] as? [String],
            let ipv4IncludedRouteSubnetMasks = options[.ipv4IncludedRouteSubnetMasks] as? [String],
            let ipv4ExcludedRouteAddresses = options[.ipv4ExcludedRouteAddresses] as? [String],
            let ipv4ExcludedRouteSubnetMasks = options[.ipv4ExcludedRouteSubnetMasks] as? [String],

            // IPv6 settings
            let ipv6Addresses = options[.ipv6Addresses] as? [String],
            let ipv6NetworkPrefixLengths = options[.ipv6NetworkPrefixLengths] as? [NSNumber],
            let ipv6IncludedRouteAddresses = options[.ipv6IncludedRouteAddresses] as? [String],
            let ipv6IncludedRouteNetworkPrefixLengths = options[.ipv6IncludedRouteNetworkPrefixLengths] as? [NSNumber],
            let ipv6ExcludedRouteAddresses = options[.ipv6ExcludedRouteAddresses] as? [String],
            let ipv6ExcludedRouteNetworkPrefixLengths = options[.ipv6ExcludedRouteNetworkPrefixLengths] as? [NSNumber]

            else {
                os_log("Starting tunnel failed: Invalid options passed", log: OSLog.default, type: .error)
                startTunnelCompletionHandler(PacketTunnelProviderError.invalidOptions)
                return
        }

        configureLogger()
        wgContext = WireGuardContext(packetFlow: self.packetFlow)

        let handle = connect(interfaceName: interfaceName, settings: wireguardSettings, mtu: mtu.uint16Value)

        if handle < 0 {
            os_log("Starting tunnel failed: Could not start WireGuard", log: OSLog.default, type: .error)
            startTunnelCompletionHandler(PacketTunnelProviderError.couldNotStartWireGuard)
            return
        }

        wgHandle = handle

        // Network settings
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: remoteAddress)

        // IPv4 settings
        let ipv4Settings = NEIPv4Settings(addresses: ipv4Addresses, subnetMasks: ipv4SubnetMasks)
        assert(ipv4IncludedRouteAddresses.count == ipv4IncludedRouteSubnetMasks.count)
        ipv4Settings.includedRoutes = zip(ipv4IncludedRouteAddresses, ipv4IncludedRouteSubnetMasks).map {
            NEIPv4Route(destinationAddress: $0.0, subnetMask: $0.1)
        }
        assert(ipv4ExcludedRouteAddresses.count == ipv4ExcludedRouteSubnetMasks.count)
        ipv4Settings.excludedRoutes = zip(ipv4ExcludedRouteAddresses, ipv4ExcludedRouteSubnetMasks).map {
            NEIPv4Route(destinationAddress: $0.0, subnetMask: $0.1)
        }
        networkSettings.ipv4Settings = ipv4Settings

        // IPv6 settings
        let ipv6Settings = NEIPv6Settings(addresses: ipv6Addresses, networkPrefixLengths: ipv6NetworkPrefixLengths)
        assert(ipv6IncludedRouteAddresses.count == ipv6IncludedRouteNetworkPrefixLengths.count)
        ipv6Settings.includedRoutes = zip(ipv6IncludedRouteAddresses, ipv6IncludedRouteNetworkPrefixLengths).map {
            NEIPv6Route(destinationAddress: $0.0, networkPrefixLength: $0.1)
        }
        assert(ipv6ExcludedRouteAddresses.count == ipv6ExcludedRouteNetworkPrefixLengths.count)
        ipv6Settings.excludedRoutes = zip(ipv6ExcludedRouteAddresses, ipv6ExcludedRouteNetworkPrefixLengths).map {
            NEIPv6Route(destinationAddress: $0.0, networkPrefixLength: $0.1)
        }
        networkSettings.ipv6Settings = ipv6Settings

        // DNS
        networkSettings.dnsSettings = NEDNSSettings(servers: dnsServers)

        // MTU
        if (mtu == 0) {
            // 0 imples automatic MTU, where we set overhead as 95 bytes,
            // 80 for WireGuard and the 15 to make sure WireGuard's padding will work.
            networkSettings.tunnelOverheadBytes = 95
        } else {
            networkSettings.mtu = mtu
        }

        setTunnelNetworkSettings(networkSettings) { (error) in
            if let error = error {
                os_log("Starting tunnel failed: Error setting network settings: %s", log: OSLog.default, type: .error, error.localizedDescription)
                startTunnelCompletionHandler(PacketTunnelProviderError.coultNotSetNetworkSettings)
            } else {
                startTunnelCompletionHandler(nil /* No errors */)
            }
        }
    }

    /// Begin the process of stopping the tunnel.
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping tunnel", log: OSLog.default, type: .info)
        wgContext?.closeTunnel()
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

    private func connect(interfaceName: String, settings: String, mtu: UInt16) -> Int32 { // swiftlint:disable:this cyclomatic_complexity
        return withStringsAsGoStrings(interfaceName, settings) { (nameGoStr, settingsGoStr) -> Int32 in
            return withUnsafeMutablePointer(to: &wgContext) { (wgCtxPtr) -> Int32 in
                return wgTurnOn(nameGoStr, settingsGoStr, mtu, { (wgCtxPtr, buf, len) -> Int in
                    autoreleasepool {
                        // read_fn: Read from the TUN interface and pass it on to WireGuard
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
                    }
                }, { (wgCtxPtr, buf, len) -> Int in
                    autoreleasepool {
                        // write_fn: Receive packets from WireGuard and write to the TUN interface
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
                    }
                },
                    wgCtxPtr)
            }
        }
    }
}

class WireGuardContext {
    private var packetFlow: NEPacketTunnelFlow
    private var outboundPackets: [NEPacket] = []
    private var isTunnelClosed: Bool = false
    private var readPacketCondition = NSCondition()

    init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }

    func closeTunnel() {
        isTunnelClosed = true
        readPacketCondition.signal()
    }

    func packetsRead(packets: [NEPacket]) {
        readPacketCondition.lock()
        outboundPackets.append(contentsOf: packets)
        readPacketCondition.unlock()
        readPacketCondition.signal()
    }

    func readPacket(isTunnelClosed: inout Bool) -> NEPacket? {
        if outboundPackets.isEmpty {
            readPacketCondition.lock()
            packetFlow.readPacketObjects(completionHandler: packetsRead)
            while outboundPackets.isEmpty && !self.isTunnelClosed {
                readPacketCondition.wait()
            }
            readPacketCondition.unlock()
        }
        isTunnelClosed = self.isTunnelClosed
        if !outboundPackets.isEmpty {
            return outboundPackets.removeFirst()
        }
        return nil
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
