// SPDX-License-Identifier: MIT
// Copyright © 2018 WireGuard LLC. All Rights Reserved.

import Foundation

enum ZipArchiveError: Error {
    case cantOpenInputZipFile
    case cantOpenOutputZipFileForWriting
    case badArchive
}

class ZipArchive {

    static func archive(inputs: [(fileName: String, contents: Data)], to destinationURL: URL) throws {
        let destinationPath = destinationURL.path
        guard let zipFile = zipOpen(destinationPath, APPEND_STATUS_CREATE) else {
            throw ZipArchiveError.cantOpenOutputZipFileForWriting
        }
        for input in inputs {
            let fileName = input.fileName
            let contents = input.contents
            zipOpenNewFileInZip(zipFile, fileName.cString(using: .utf8), nil, nil, 0, nil, 0, nil, Z_DEFLATED, Z_DEFAULT_COMPRESSION)
            contents.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> Void in
                zipWriteInFileInZip(zipFile, UnsafeRawPointer(ptr), UInt32(contents.count))
            }
            zipCloseFileInZip(zipFile)
        }
        zipClose(zipFile, nil)
    }

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

            if let fileURL = URL(string: String(cString: fileNameBuffer)),
                !fileURL.hasDirectoryPath,
                requiredFileExtensions.contains(fileURL.pathExtension) {

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
                results.append((fileName: fileURL.lastPathComponent, contents: unzippedData))
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
