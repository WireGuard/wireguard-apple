// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All rights reserved.

import Foundation

enum ZipArchiveError: Error {
    case cantOpenInputZipFile
    case badArchive
}

class ZipArchive {

    static func unarchive(url: URL, requiredFileExtensions: [String]) throws -> [(fileName: String, contents: Data)] {

        var results: [(fileName: String, contents: Data)] = []

        guard let zipFile = unzOpen64(url.path) else {
            throw ZipArchiveError.cantOpenInputZipFile
        }
        defer {
            unzClose(zipFile)
        }
        guard (unzGoToFirstFile(zipFile) == UNZ_OK) else {
            throw ZipArchiveError.badArchive
        }

        var resultOfGoToNextFile: Int32
        repeat {
            guard (unzOpenCurrentFile(zipFile) == UNZ_OK) else {
                throw ZipArchiveError.badArchive
            }

            let bufferSize = 1024
            var fileNameBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
            var dataBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)

            defer {
                fileNameBuffer.deallocate()
                dataBuffer.deallocate()
            }

            guard (unzGetCurrentFileInfo64(zipFile, nil, fileNameBuffer, UInt(bufferSize), nil, 0, nil, 0) == UNZ_OK) else {
                throw ZipArchiveError.badArchive
            }

            let fileName = String(cString: fileNameBuffer)
            let fileExtension = URL(string: fileName)?.pathExtension ?? ""

            if (requiredFileExtensions.contains(fileExtension)) {
                var unzippedData = Data()
                var bytesRead: Int32 = 0
                repeat {
                    bytesRead = unzReadCurrentFile(zipFile, dataBuffer, UInt32(bufferSize))
                    if (bytesRead > 0) {
                        let dataRead = dataBuffer.withMemoryRebound(to: UInt8.self, capacity: bufferSize) {
                            (buf: UnsafeMutablePointer<UInt8>) -> Data in
                            return Data(bytes: buf, count: Int(bytesRead))
                        }
                        unzippedData.append(dataRead)
                    }
                } while (bytesRead > 0)
                results.append((fileName: fileName, contents: unzippedData))
            }

            guard (unzCloseCurrentFile(zipFile) == UNZ_OK) else {
                throw ZipArchiveError.badArchive
            }

            resultOfGoToNextFile = unzGoToNextFile(zipFile)
        } while (resultOfGoToNextFile == UNZ_OK)

        if (resultOfGoToNextFile == UNZ_END_OF_LIST_OF_FILE) {
            return results
        } else {
            throw ZipArchiveError.badArchive
        }
    }
}
