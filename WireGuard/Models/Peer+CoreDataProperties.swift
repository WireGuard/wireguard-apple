//
//  Copyright © 2018 WireGuard LLC. All rights reserved.
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
    @NSManaged public var persistentKeepalive: Int32
    @NSManaged public var tunnel: Tunnel?

}
