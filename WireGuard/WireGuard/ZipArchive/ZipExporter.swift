// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

enum ZipExporterError: Error {
    case noTunnelsToExport
}

class ZipExporter {
    static func exportConfigFiles(tunnelConfigurations: [TunnelConfiguration], to destinationURL: URL) throws {

        guard (!tunnelConfigurations.isEmpty) else { throw ZipExporterError.noTunnelsToExport }

        var inputsToArchiver: [(fileName: String, contents: Data)] = []

        var lastTunnelName: String = ""
        for tunnelConfiguration in tunnelConfigurations {
            if let contents = WgQuickConfigFileWriter.writeConfigFile(from: tunnelConfiguration) {
                let name = tunnelConfiguration.interface.name
                if (name.isEmpty || name == lastTunnelName) { continue }
                inputsToArchiver.append((fileName: "\(name).conf", contents: contents))
                lastTunnelName = name
            }
        }
        try ZipArchive.archive(inputs: inputsToArchiver, to: destinationURL)
    }
}
