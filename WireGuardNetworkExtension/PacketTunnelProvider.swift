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

    /// The completion handler to call when the tunnel is fully established.
    var pendingStartCompletion: ((Error?) -> Void)?

    /// The completion handler to call when the tunnel is fully disconnected.
    var pendingStopCompletion: (() -> Void)?

    // MARK: NEPacketTunnelProvider

    /// Begin the process of establishing the tunnel.
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel", log: Log.general, type: .info)

        //TODO tunnel settings
        if wireGuardWrapper.turnOn(withInterfaceName: "test", settingsString: "") {
            // Success
//            completionHandler(nil)

            //TODO obtain network config from WireGuard config or remote.
            // route all traffic to VPN
            let defaultRoute = NEIPv4Route.default()
//            defaultRoute.gatewayAddress = gateway

            let ipv4Settings = NEIPv4Settings(addresses: ["149.248.160.60"], subnetMasks: ["255.255.255.255"])
            ipv4Settings.includedRoutes = [defaultRoute]
            ipv4Settings.excludedRoutes = []

//            let dnsSettings = NEDNSSettings(servers: dnsServers)

            let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "149.248.160.60")
            newSettings.ipv4Settings = ipv4Settings
//            newSettings.dnsSettings = dnsSettings
//            newSettings.mtu = cfg.mtu

            setTunnelNetworkSettings(newSettings, completionHandler: completionHandler)

        } else {
            completionHandler(PacketTunnelProviderError.tunnelSetupFailed)
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
