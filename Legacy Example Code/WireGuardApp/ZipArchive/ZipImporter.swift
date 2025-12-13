// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation

class ZipImporter {
    static func importConfigFiles(from url: URL, completion: @escaping (Result<[TunnelConfiguration?], ZipArchiveError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var unarchivedFiles: [(fileBaseName: String, contents: Data)]
            do {
                unarchivedFiles = try ZipArchive.unarchive(url: url, requiredFileExtensions: ["conf"])
                for (index, unarchivedFile) in unarchivedFiles.enumerated().reversed() {
                    let fileBaseName = unarchivedFile.fileBaseName
                    let trimmedName = fileBaseName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty {
                        unarchivedFiles[index].fileBaseName = trimmedName
                    } else {
                        unarchivedFiles.remove(at: index)
                    }
                }

                if unarchivedFiles.isEmpty {
                    throw ZipArchiveError.noTunnelsInZipArchive
                }
            } catch let error as ZipArchiveError {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            } catch {
                fatalError()
            }

            unarchivedFiles.sort { TunnelsManager.tunnelNameIsLessThan($0.fileBaseName, $1.fileBaseName) }
            var configs: [TunnelConfiguration?] = Array(repeating: nil, count: unarchivedFiles.count)
            for (index, file) in unarchivedFiles.enumerated() {
                if index > 0 && file == unarchivedFiles[index - 1] {
                    continue
                }
                guard let fileContents = String(data: file.contents, encoding: .utf8) else { continue }
                guard let tunnelConfig = try? TunnelConfiguration(fromWgQuickConfig: fileContents, called: file.fileBaseName) else { continue }
                configs[index] = tunnelConfig
            }
            DispatchQueue.main.async { completion(.success(configs)) }
        }
    }
}
