import Foundation

enum SimpleZipArchive {

    struct Entry {
        let fileURL: URL
        let archivePath: String
    }

    private struct CentralDirectoryRecord {
        let nameData: Data
        let crc32: UInt32
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let localHeaderOffset: UInt32
    }

    static func createArchive(at zipURL: URL, entries: [Entry]) throws {
        let fm = FileManager.default
        try? fm.removeItem(at: zipURL)
        fm.createFile(atPath: zipURL.path, contents: nil)

        guard let handle = try? FileHandle(forWritingTo: zipURL) else {
            throw NSError(domain: "SimpleZipArchive", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Cannot create zip file"])
        }

        var centralRecords: [CentralDirectoryRecord] = []
        var offset: UInt32 = 0

        for entry in entries {
            let fileData = try Data(contentsOf: entry.fileURL)
            let crc = CRC32.compute(for: fileData)
            let nameData = Data(entry.archivePath.utf8)
            let dataSize = UInt32(fileData.count)

            try writeLocalFileHeader(
                to: handle,
                fileNameData: nameData,
                crc32: crc,
                compressedSize: dataSize,
                uncompressedSize: dataSize
            )
            try handle.write(contentsOf: nameData)
            try handle.write(contentsOf: fileData)

            centralRecords.append(
                CentralDirectoryRecord(
                    nameData: nameData,
                    crc32: crc,
                    compressedSize: dataSize,
                    uncompressedSize: dataSize,
                    localHeaderOffset: offset
                )
            )

            offset = offset &+ 30 &+ UInt32(nameData.count) &+ dataSize
        }

        let centralDirectoryOffset = offset
        var centralDirectorySize: UInt32 = 0

        for record in centralRecords {
            try writeCentralDirectoryHeader(to: handle, record: record)
            try handle.write(contentsOf: record.nameData)
            centralDirectorySize = centralDirectorySize &+ 46 &+ UInt32(record.nameData.count)
        }

        try writeEndOfCentralDirectory(
            to: handle,
            entryCount: UInt16(centralRecords.count),
            centralDirectorySize: centralDirectorySize,
            centralDirectoryOffset: centralDirectoryOffset
        )

        try handle.close()
    }

    static func directorySize(at url: URL) throws -> UInt64 {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: keys)

        var total: UInt64 = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else { continue }
            total += UInt64(values.fileSize ?? 0)
        }
        return total
    }

    static func allFiles(in directoryURL: URL, prefix: String? = nil) throws -> [Entry] {
        let fm = FileManager.default
        let enumerator = fm.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey])
        var entries: [Entry] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: directoryURL.path + "/", with: "")
            let archivePath: String
            if let prefix, !prefix.isEmpty {
                archivePath = "\(prefix)/\(relativePath)"
            } else {
                archivePath = relativePath
            }

            entries.append(Entry(fileURL: fileURL, archivePath: archivePath))
        }

        return entries.sorted { $0.archivePath < $1.archivePath }
    }

    private static func writeLocalFileHeader(
        to handle: FileHandle,
        fileNameData: Data,
        crc32: UInt32,
        compressedSize: UInt32,
        uncompressedSize: UInt32
    ) throws {
        var header = Data()
        header.appendLE(UInt32(0x04034b50))
        header.appendLE(UInt16(20))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(crc32)
        header.appendLE(compressedSize)
        header.appendLE(uncompressedSize)
        header.appendLE(UInt16(fileNameData.count))
        header.appendLE(UInt16(0))
        try handle.write(contentsOf: header)
    }

    private static func writeCentralDirectoryHeader(
        to handle: FileHandle,
        record: CentralDirectoryRecord
    ) throws {
        var header = Data()
        header.appendLE(UInt32(0x02014b50))
        header.appendLE(UInt16(20))
        header.appendLE(UInt16(20))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(record.crc32)
        header.appendLE(record.compressedSize)
        header.appendLE(record.uncompressedSize)
        header.appendLE(UInt16(record.nameData.count))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(UInt32(0))
        header.appendLE(record.localHeaderOffset)
        try handle.write(contentsOf: header)
    }

    private static func writeEndOfCentralDirectory(
        to handle: FileHandle,
        entryCount: UInt16,
        centralDirectorySize: UInt32,
        centralDirectoryOffset: UInt32
    ) throws {
        var footer = Data()
        footer.appendLE(UInt32(0x06054b50))
        footer.appendLE(UInt16(0))
        footer.appendLE(UInt16(0))
        footer.appendLE(entryCount)
        footer.appendLE(entryCount)
        footer.appendLE(centralDirectorySize)
        footer.appendLE(centralDirectoryOffset)
        footer.appendLE(UInt16(0))
        try handle.write(contentsOf: footer)
    }
}

private enum CRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { index -> UInt32 in
            var c = UInt32(index)
            for _ in 0..<8 {
                c = (c & 1) == 1 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    static func compute(for data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let idx = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = CRC32.table[idx] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: MemoryLayout<UInt16>.size))
    }

    mutating func appendLE(_ value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: MemoryLayout<UInt32>.size))
    }
}
