/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import Compression

/// Minimal ZIP reader for Minecraft native jars (stored / deflate).
enum ZipExtractor {
    static func extract(jar: URL, to directory: URL) throws {
        let data = try Data(contentsOf: jar)
        guard data.count >= 22 else { return }

        // Find End of Central Directory
        var eocdOffset: Int?
        let minEOCD = max(0, data.count - 65557)
        for i in stride(from: data.count - 22, through: minEOCD, by: -1) {
            if data[i] == 0x50, data[i + 1] == 0x4B, data[i + 2] == 0x05, data[i + 3] == 0x06 {
                eocdOffset = i
                break
            }
        }
        guard let eocd = eocdOffset else { return }
        let centralDirOffset = Int(readUInt32(data, eocd + 16))
        let entryCount = Int(readUInt16(data, eocd + 10))

        var offset = centralDirOffset
        for _ in 0..<entryCount {
            guard offset + 46 <= data.count,
                  data[offset] == 0x50, data[offset + 1] == 0x4B,
                  data[offset + 2] == 0x01, data[offset + 3] == 0x02
            else { break }

            let compression = Int(readUInt16(data, offset + 10))
            let compressedSize = Int(readUInt32(data, offset + 20))
            let nameLength = Int(readUInt16(data, offset + 28))
            let extraLength = Int(readUInt16(data, offset + 30))
            let commentLength = Int(readUInt16(data, offset + 32))
            let localHeaderOffset = Int(readUInt32(data, offset + 42))
            let nameData = data.subdata(in: (offset + 46)..<(offset + 46 + nameLength))
            let name = String(data: nameData, encoding: .utf8) ?? ""
            offset += 46 + nameLength + extraLength + commentLength

            if name.hasSuffix("/") || name.isEmpty { continue }
            if name.lowercased().hasPrefix("meta-inf/") { continue }

            guard localHeaderOffset + 30 <= data.count else { continue }
            let localNameLength = Int(readUInt16(data, localHeaderOffset + 26))
            let localExtraLength = Int(readUInt16(data, localHeaderOffset + 28))
            let dataStart = localHeaderOffset + 30 + localNameLength + localExtraLength
            let dataEnd = dataStart + compressedSize
            guard dataEnd <= data.count else { continue }
            let payload = data.subdata(in: dataStart..<dataEnd)

            let destination = directory.appendingPathComponent(name)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            switch compression {
            case 0:
                try payload.write(to: destination, options: .atomic)
            case 8:
                let uncompressedSize = Int(readUInt32(data, offset - commentLength - extraLength - nameLength - 46 + 24))
                // Prefer size from central directory field we already passed — re-read:
                let trueUncompressed = Int(readUInt32(
                    data,
                    (offset - (46 + nameLength + extraLength + commentLength)) + 24
                ))
                if let inflated = inflate(payload, expectedSize: trueUncompressed > 0 ? trueUncompressed : uncompressedSize) {
                    try inflated.write(to: destination, options: .atomic)
                }
            default:
                continue
            }
        }
    }

    private static func inflate(_ data: Data, expectedSize: Int) -> Data? {
        guard expectedSize > 0 else { return nil }
        let destCapacity = expectedSize
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destCapacity)
        defer { destinationBuffer.deallocate() }
        let decodedCount: Int = data.withUnsafeBytes { raw in
            guard let source = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                destinationBuffer,
                destCapacity,
                source,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        // ZIP uses raw deflate; try COMPRESSION_ZLIB first then raw via zlib wrapper fallback.
        if decodedCount > 0 {
            return Data(bytes: destinationBuffer, count: decodedCount)
        }
        // Raw deflate (no zlib header): Compression framework COMPRESSION_ZLIB expects zlib wrap.
        // Prepend a synthetic approach using compression_decode_buffer with COMPRESSION_ZLIB often fails for raw.
        // Use a minimal inflate by wrapping with zlib header 0x78 0x01 and adler — skip if fails.
        var wrapped = Data([0x78, 0x01])
        wrapped.append(data)
        let decoded2: Int = wrapped.withUnsafeBytes { raw in
            guard let source = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                destinationBuffer,
                destCapacity,
                source,
                wrapped.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        guard decoded2 > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: decoded2)
    }

    private static func readUInt16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
