// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit

class QuickActionItem: UIApplicationShortcutItem {
    static let type = "WireGuardTunnelActivateAndShow"

    init(tunnelName: String) {
        super.init(type: QuickActionItem.type, localizedTitle: tunnelName, localizedSubtitle: nil, icon: nil, userInfo: nil)
    }

    static func createItems(allTunnelNames: [String]) -> [QuickActionItem] {
        let numberOfItems = 10
        // Currently, only 4 items shown by iOS, but that can increase in the future.
        // iOS will discard additional items we give it.
        var tunnelNames = RecentTunnelsTracker.recentlyActivatedTunnelNames(limit: numberOfItems)
        let numberOfSlotsRemaining = numberOfItems - tunnelNames.count
        if numberOfSlotsRemaining > 0 {
            let moreTunnels = allTunnelNames.filter { !tunnelNames.contains($0) }.prefix(numberOfSlotsRemaining)
            tunnelNames.append(contentsOf: moreTunnels)
        }
        return tunnelNames.map { QuickActionItem(tunnelName: $0) }
    }
}
