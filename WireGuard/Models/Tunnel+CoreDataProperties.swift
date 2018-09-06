//
//  Tunnel+CoreDataProperties.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 23-05-18.
//  Copyright © 2018 WireGuard LLC. All rights reserved.
//
//

import Foundation
import CoreData

extension Tunnel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tunnel> {
        return NSFetchRequest<Tunnel>(entityName: "Tunnel")
    }

    @NSManaged public var tunnelIdentifier: String?
    @NSManaged public var title: String?
    @NSManaged public var interface: Interface?
    @NSManaged public var peers: NSOrderedSet?

}

// MARK: Generated accessors for peers
extension Tunnel {

    @objc(insertObject:inPeersAtIndex:)
    @NSManaged public func insertIntoPeers(_ value: Peer, at idx: Int)

    @objc(removeObjectFromPeersAtIndex:)
    @NSManaged public func removeFromPeers(at idx: Int)

    @objc(insertPeers:atIndexes:)
    @NSManaged public func insertIntoPeers(_ values: [Peer], at indexes: NSIndexSet)

    @objc(removePeersAtIndexes:)
    @NSManaged public func removeFromPeers(at indexes: NSIndexSet)

    @objc(replaceObjectInPeersAtIndex:withObject:)
    @NSManaged public func replacePeers(at idx: Int, with value: Peer)

    @objc(replacePeersAtIndexes:withPeers:)
    @NSManaged public func replacePeers(at indexes: NSIndexSet, with values: [Peer])

    @objc(addPeersObject:)
    @NSManaged public func addToPeers(_ value: Peer)

    @objc(removePeersObject:)
    @NSManaged public func removeFromPeers(_ value: Peer)

    @objc(addPeers:)
    @NSManaged public func addToPeers(_ values: NSOrderedSet)

    @objc(removePeers:)
    @NSManaged public func removeFromPeers(_ values: NSOrderedSet)

}
