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

}
