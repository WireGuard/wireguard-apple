//
//  Profile+CoreDataProperties.swift
//  Wireguard
//
//  Created by Jeroen Leenarts on 23-05-18.
//  Copyright © 2018 Wireguard. All rights reserved.
//
//

import Foundation
import CoreData


extension Profile {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Profile> {
        return NSFetchRequest<Profile>(entityName: "Profile")
    }

    @NSManaged public var title: String?
    @NSManaged public var peers: NSSet?
    @NSManaged public var interface: Interface?

}

// MARK: Generated accessors for peers
extension Profile {

    @objc(addPeersObject:)
    @NSManaged public func addToPeers(_ value: Peer)

    @objc(removePeersObject:)
    @NSManaged public func removeFromPeers(_ value: Peer)

    @objc(addPeers:)
    @NSManaged public func addToPeers(_ values: NSSet)

    @objc(removePeers:)
    @NSManaged public func removeFromPeers(_ values: NSSet)

}
