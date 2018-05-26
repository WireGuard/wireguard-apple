//
//  Tunnel+CoreDataProperties.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 23-05-18.
//  Copyright © 2018 WireGuard. All rights reserved.
//
//

import Foundation
import CoreData

extension Tunnel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tunnel> {
        return NSFetchRequest<Tunnel>(entityName: "Tunnel")
    }

    @NSManaged public var title: String?
    @NSManaged public var peers: NSSet?
    @NSManaged public var interface: Interface?

}

// MARK: Generated accessors for peers
extension Tunnel {

    @objc(addPeersObject:)
    @NSManaged public func addToPeers(_ value: Peer)

    @objc(removePeersObject:)
    @NSManaged public func removeFromPeers(_ value: Peer)

    @objc(addPeers:)
    @NSManaged public func addToPeers(_ values: NSSet)

    @objc(removePeers:)
    @NSManaged public func removeFromPeers(_ values: NSSet)

}
