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

    /// A reference to the WireGuard wrapper object.
    let wireGuardWrapper = WireGuardGoWrapper()

    // MARK: NEPacketTunnelProvider

    /// Begin the process of establishing the tunnel.
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel", log: Log.general, type: .info)

        let config = self.protocolConfiguration as! NETunnelProviderProtocol // swiftlint:disable:this force_cast
        let interfaceName = config.providerConfiguration![PCKeys.title.rawValue]! as! String // swiftlint:disable:this force_cast
        let mtu = config.providerConfiguration![PCKeys.mtu.rawValue] as? NSNumber
        let settings = config.providerConfiguration![PCKeys.settings.rawValue]! as! String // swiftlint:disable:this force_cast
        let endpoints = config.providerConfiguration?[PCKeys.endpoints.rawValue] as? String ?? ""
        let addresses = (config.providerConfiguration?[PCKeys.addresses.rawValue] as? String ?? "").split(separator: ",")

        settings.split(separator: "\n").forEach {os_log("Tunnel config: %{public}s", log: Log.general, type: .info, String($0))}

        if wireGuardWrapper.turnOn(withInterfaceName: interfaceName, settingsString: settings) {
            //TODO: Hardcoded values for addresses
            // IPv4 settings
            let ipv4Settings = NEIPv4Settings(addresses: ["10.50.10.171"], subnetMasks: ["255.255.224.0"])
            ipv4Settings.includedRoutes = [NEIPv4Route.default()]
            let validatedEndpoints = endpoints.split(separator: ",").compactMap { try? Endpoint(endpointString: String($0)) }.compactMap {$0}
            ipv4Settings.excludedRoutes = validatedEndpoints.filter { $0.addressType == .IPv4}.map {
                NEIPv4Route(destinationAddress: $0.ipAddress, subnetMask: "255.255.255.255")}

            // IPv6 settings
            //TODO: Hardcoded values for address
            let ipv6Settings = NEIPv6Settings(addresses: ["2607:f938:3001:4000::aac"], networkPrefixLengths: [64])
            ipv6Settings.includedRoutes = [NEIPv6Route.default()]
            ipv6Settings.excludedRoutes = validatedEndpoints.filter { $0.addressType == .IPv6}.map { NEIPv6Route(destinationAddress: $0.ipAddress, networkPrefixLength: 0)}

            //TODO: Hardcoded values for tunnelRemoteAddress
            let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "149.248.160.60")

            newSettings.ipv4Settings = ipv4Settings
            //TODO apply IPv6
//            newSettings.ipv6Settings = ipv6Settings
            newSettings.tunnelOverheadBytes = 80
            if let dns = config.providerConfiguration?[PCKeys.dns.rawValue] as? String {
                var splitDnsEntries = dns.split(separator: ",").map {String($0)}
                //TODO apple IPv6 DNS
//                splitDnsEntries.append("2606:ed00:2:babe::2")
                let dnsSettings = NEDNSSettings(servers: splitDnsEntries)
                newSettings.dnsSettings = dnsSettings
            }
            if let mtu = mtu, mtu.intValue > 0 {
                newSettings.mtu = mtu
            }

            setTunnelNetworkSettings(newSettings) { [weak self](error) in
                self?.wireGuardWrapper.packetFlow = self?.packetFlow
                self?.wireGuardWrapper.configured = true
                self?.wireGuardWrapper.startReadingPackets()
                completionHandler(error)
            }

        } else {
            self.wireGuardWrapper.packetFlow = self.packetFlow
            completionHandler(PacketTunnelProviderError.tunnelSetupFailed)
            wireGuardWrapper.configured = false
        }
    }

    /// Begin the process of stopping the tunnel.
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping tunnel", log: Log.general, type: .info)

        wireGuardWrapper.turnOff()
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
