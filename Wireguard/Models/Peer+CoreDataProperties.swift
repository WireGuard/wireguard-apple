//
//  Peer+CoreDataProperties.swift
//  
//
//  Created by Jeroen Leenarts on 23-05-18.
//
//

import Foundation
import CoreData

extension Peer {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Peer> {
        return NSFetchRequest<Peer>(entityName: "Peer")
    }

    @NSManaged public var publicKey: String?
    @NSManaged public var presharedKey: String?
    @NSManaged public var allowedIPs: String?
    @NSManaged public var endpoint: String?
    @NSManaged public var persistentKeepalive: Int16
    @NSManaged public var tunnel: Tunnel?

}
