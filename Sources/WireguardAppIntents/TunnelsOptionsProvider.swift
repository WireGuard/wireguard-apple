// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct TunnelsOptionsProvider: DynamicOptionsProvider {
    @Dependency
    var tunnelsManager: TunnelsManager

    func results() async throws -> [String] {
        let tunnelsNames = tunnelsManager.mapTunnels { $0.name }
        return tunnelsNames
    }
}
