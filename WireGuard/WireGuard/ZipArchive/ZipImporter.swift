// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import UIKit

enum ZipImporterError: WireGuardAppError {
    case noTunnelsInZipArchive

    func alertText() -> (String, String)? {
        switch (self) {
        case .noTunnelsInZipArchive:
            return ("No tunnels in zip archive", "No .conf tunnel files were found inside the zip archive.")
        }
    }
}

class ZipImporter {
    static func importConfigFiles(from url: URL, completion: @escaping (WireGuardResult<[TunnelConfiguration?]>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var unarchivedFiles: [(fileBaseName: String, contents: Data)]
            do {
                unarchivedFiles = try ZipArchive.unarchive(url: url, requiredFileExtensions: ["conf"])
                for (index, unarchivedFile) in unarchivedFiles.enumerated().reversed() {
                    let fileBaseName = unarchivedFile.fileBaseName
                    let trimmedName = fileBaseName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if (!trimmedName.isEmpty) {
                        unarchivedFiles[index].fileBaseName = trimmedName
                    } else {
                        unarchivedFiles.remove(at: index)
                    }
                }

                if (unarchivedFiles.isEmpty) {
                    throw ZipImporterError.noTunnelsInZipArchive
                }
            } catch (let error as WireGuardAppError) {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            } catch {
                fatalError()
            }

            unarchivedFiles.sort { $0.fileBaseName < $1.fileBaseName }
            var configs = Array<TunnelConfiguration?>(repeating: nil, count: unarchivedFiles.count)
            for (index, file) in unarchivedFiles.enumerated() {
                if (index > 0 && file == unarchivedFiles[index - 1]) {
                    continue
                }
                guard let fileContents = String(data: file.contents, encoding: .utf8) else {
                    continue
                }
                guard let tunnelConfig = try? WgQuickConfigFileParser.parse(fileContents, name: file.fileBaseName) else {
                    continue
                }
                configs[index] = tunnelConfig
            }
            DispatchQueue.main.async { completion(.success(configs)) }
        }
    }
}
