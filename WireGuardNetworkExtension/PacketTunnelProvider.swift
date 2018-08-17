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
        let addresses = (config.providerConfiguration?[PCKeys.addresses.rawValue] as? String ?? "").commaSeparatedToArray()

        let validatedEndpoints = endpoints.commaSeparatedToArray().compactMap { try? Endpoint(endpointString: String($0)) }.compactMap {$0}
        let validatedAddresses = addresses.compactMap { try? CIDRAddress(stringRepresentation: String($0)) }.compactMap { $0 }

        if let firstEndpoint = validatedEndpoints.first, wireGuardWrapper.turnOn(withInterfaceName: interfaceName, settingsString: settings) {
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

            setTunnelNetworkSettings(newSettings) { [weak self](error) in
                self?.wireGuardWrapper.packetFlow = self?.packetFlow
                self?.wireGuardWrapper.configured = true
                self?.wireGuardWrapper.startReadingPackets()
                completionHandler(error)
            }

        } else {
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
