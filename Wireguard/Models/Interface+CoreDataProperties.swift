//
//  Interface+CoreDataProperties.swift
//  
//
//  Created by Jeroen Leenarts on 23-05-18.
//
//

import Foundation
import CoreData

extension Interface {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Interface> {
        return NSFetchRequest<Interface>(entityName: "Interface")
    }

    @NSManaged public var privateKey: String?
    @NSManaged public var listenPort: Int16
    @NSManaged public var fwMark: Int32
    @NSManaged public var profile: Profile?

}
