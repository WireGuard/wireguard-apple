// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

enum ZipImporterError: Error {
    case noTunnelsInZipArchive
}

class ZipImporter {
    let url: URL
    init(url: URL) {
        self.url = url
    }

    func importConfigFiles() throws -> [TunnelConfiguration?] {
        var unarchivedFiles: [(fileName: String, contents: Data)] = try ZipArchive.unarchive(url: url, requiredFileExtensions: ["conf"])

        for (i, unarchivedFile) in unarchivedFiles.enumerated().reversed() {
            let fileBaseName = URL(string: unarchivedFile.fileName)?.deletingPathExtension().lastPathComponent
            if let trimmedName = fileBaseName?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedName.isEmpty {
                unarchivedFiles[i].fileName = trimmedName
            } else {
                unarchivedFiles.remove(at: i)
            }
        }

        if (unarchivedFiles.isEmpty) {
            throw ZipImporterError.noTunnelsInZipArchive
        }

        unarchivedFiles.sort { $0.fileName < $1.fileName }
        var configs = Array<TunnelConfiguration?>(repeating: nil, count: unarchivedFiles.count)
        for (i, file) in unarchivedFiles.enumerated() {
            if (i > 0 && file == unarchivedFiles[i - 1]) {
                continue
            }
            guard let fileContents = String(data: file.contents, encoding: .utf8) else {
                continue
            }
            guard let tunnelConfig = try? WgQuickConfigFileParser.parse(fileContents, name: file.fileName) else {
                continue
            }
            configs[i] = tunnelConfig
        }
        return configs
    }
}
