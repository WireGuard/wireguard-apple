// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation

enum ZipArchiveError: WireGuardAppError {
    case cantOpenInputZipFile
    case cantOpenOutputZipFileForWriting
    case badArchive
    case noTunnelsInZipArchive

    var alertText: AlertText {
        switch self {
        case .cantOpenInputZipFile:
            return (tr("alertCantOpenInputZipFileTitle"), tr("alertCantOpenInputZipFileMessage"))
        case .cantOpenOutputZipFileForWriting:
            return (tr("alertCantOpenOutputZipFileForWritingTitle"), tr("alertCantOpenOutputZipFileForWritingMessage"))
        case .badArchive:
            return (tr("alertBadArchiveTitle"), tr("alertBadArchiveMessage"))
        case .noTunnelsInZipArchive:
            return (tr("alertNoTunnelsInImportedZipArchiveTitle"), tr("alertNoTunnelsInImportedZipArchiveMessage"))
        }
    }
}

enum ZipArchive {}

extension ZipArchive {

    static func archive(inputs: [(fileName: String, contents: Data)], to destinationURL: URL) throws {
        let destinationPath = destinationURL.path
        guard let zipFile = zipOpen(destinationPath, APPEND_STATUS_CREATE) else {
            throw ZipArchiveError.cantOpenOutputZipFileForWriting
        }
        for input in inputs {
            let fileName = input.fileName
            let contents = input.contents
            zipOpenNewFileInZip(zipFile, fileName.cString(using: .utf8), nil, nil, 0, nil, 0, nil, Z_DEFLATED, Z_DEFAULT_COMPRESSION)
            contents.withUnsafeBytes { rawBufferPointer -> Void in
                zipWriteInFileInZip(zipFile, rawBufferPointer.baseAddress, UInt32(contents.count))
            }
            zipCloseFileInZip(zipFile)
        }
        zipClose(zipFile, nil)
    }

    static func unarchive(url: URL, requiredFileExtensions: [String]) throws -> [(fileBaseName: String, contents: Data)] {

        var results = [(fileBaseName: String, contents: Data)]()
        let requiredFileExtensionsLowercased = requiredFileExtensions.map { $0.lowercased() }

        guard let zipFile = unzOpen64(url.path) else {
            throw ZipArchiveError.cantOpenInputZipFile
        }
        defer {
            unzClose(zipFile)
        }
        guard unzGoToFirstFile(zipFile) == UNZ_OK else { throw ZipArchiveError.badArchive }

        var resultOfGoToNextFile: Int32
        repeat {
            guard unzOpenCurrentFile(zipFile) == UNZ_OK else { throw ZipArchiveError.badArchive }

            let bufferSize = 16384 // 16 KiB
            let fileNameBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
            let dataBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)

            defer {
                fileNameBuffer.deallocate()
                dataBuffer.deallocate()
            }

            guard unzGetCurrentFileInfo64(zipFile, nil, fileNameBuffer, UInt(bufferSize), nil, 0, nil, 0) == UNZ_OK else { throw ZipArchiveError.badArchive }

            let lastChar = String(cString: fileNameBuffer).suffix(1)
            let isDirectory = (lastChar == "/" || lastChar == "\\")
            let fileURL = URL(fileURLWithFileSystemRepresentation: fileNameBuffer, isDirectory: isDirectory, relativeTo: nil)

            if !isDirectory && requiredFileExtensionsLowercased.contains(fileURL.pathExtension.lowercased()) {
                var unzippedData = Data()
                var bytesRead: Int32 = 0
                repeat {
                    bytesRead = unzReadCurrentFile(zipFile, dataBuffer, UInt32(bufferSize))
                    if bytesRead > 0 {
                        let dataRead = dataBuffer.withMemoryRebound(to: UInt8.self, capacity: bufferSize) {
                            return Data(bytes: $0, count: Int(bytesRead))
                        }
                        unzippedData.append(dataRead)
                    }
                } while bytesRead > 0
                results.append((fileBaseName: fileURL.deletingPathExtension().lastPathComponent, contents: unzippedData))
            }

            guard unzCloseCurrentFile(zipFile) == UNZ_OK else { throw ZipArchiveError.badArchive }

            resultOfGoToNextFile = unzGoToNextFile(zipFile)
        } while resultOfGoToNextFile == UNZ_OK

        if resultOfGoToNextFile == UNZ_END_OF_LIST_OF_FILE {
            return results
        } else {
            throw ZipArchiveError.badArchive
        }
    }
}
