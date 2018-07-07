//
//  PacketTunnelProvider.swift
//  WireGuardNetworkExtension
//
//  Created by Jeroen Leenarts on 19-06-18.
//  Copyright © 2018 WireGuard. All rights reserved.
//

import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {
    let wireGuardWrapper = WireGuardGoWrapper()

    private let tunnelQueue = DispatchQueue(label: PacketTunnelProvider.description())

    //TODO create a way to transfer config into extension

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel", log: Log.general, type: .info)
        // Add code here to start the process of connecting the tunnel.

        //TODO get a settings string in here.
        tunnelQueue.sync {
            wireGuardWrapper.turnOn(withInterfaceName: "TODO", settingsString: "TODO")
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping tunnel", log: Log.general, type: .info)
        // Add code here to start the process of stopping the tunnel.
        tunnelQueue.sync {
            wireGuardWrapper.turnOff()
        }
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }

    private func loopReadPackets(_ handler: @escaping ([Data]?, Error?) -> Void) {
        packetFlow.readPackets { [weak self] (_, _) in
            // TODO write packets into the tunnel
            self?.loopReadPackets(handler)
        }
    }

    func writePacket(_ packet: Data, completionHandler: ((Error?) -> Void)?) {
        packetFlow.writePackets([packet], withProtocols: [AF_INET] as [NSNumber])
        completionHandler?(nil)
    }

    func writePackets(_ packets: [Data], completionHandler: ((Error?) -> Void)?) {
        let protocols = [Int32](repeating: AF_INET, count: packets.count) as [NSNumber]
        packetFlow.writePackets(packets, withProtocols: protocols)
        completionHandler?(nil)
    }
}
