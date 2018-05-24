//
//  Address+CoreDataProperties.swift
//  Wireguard
//
//  Created by Jeroen Leenarts on 24-05-18.
//  Copyright © 2018 Wireguard. All rights reserved.
//
//

import Foundation
import CoreData

extension Address {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Address> {
        return NSFetchRequest<Address>(entityName: "Address")
    }

    @NSManaged public var address: String?
    @NSManaged public var interface: Interface?

}
