// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

enum ZipExporterError: WireGuardAppError {
    case noTunnelsToExport

    var alertText: AlertText {
        return (tr("alertNoTunnelsToExportTitle"), tr("alertNoTunnelsToExportMessage"))
    }
}

class ZipExporter {
    static func exportConfigFiles(tunnelConfigurations: [TunnelConfiguration], to url: URL, completion: @escaping (WireGuardAppError?) -> Void) {

        guard !tunnelConfigurations.isEmpty else {
            completion(ZipExporterError.noTunnelsToExport)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var inputsToArchiver: [(fileName: String, contents: Data)] = []
            var lastTunnelName: String = ""
            for tunnelConfiguration in tunnelConfigurations {
                if let contents = WgQuickConfigFileWriter.writeConfigFile(from: tunnelConfiguration) {
                    let name = tunnelConfiguration.interface.name
                    if name.isEmpty || name == lastTunnelName { continue }
                    inputsToArchiver.append((fileName: "\(name).conf", contents: contents))
                    lastTunnelName = name
                }
            }
            do {
                try ZipArchive.archive(inputs: inputsToArchiver, to: url)
            } catch let error as WireGuardAppError {
                DispatchQueue.main.async { completion(error) }
                return
            } catch {
                fatalError()
            }
            DispatchQueue.main.async { completion(nil) }
        }
    }
}
