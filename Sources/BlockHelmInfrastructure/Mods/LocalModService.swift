/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmApplication
import BlockHelmDomain

public final class LocalContentServiceImpl: LocalContentService, @unchecked Sendable {
    public init() {}

    public func directory(for instance: GameInstance, kind: ModrinthProjectKind) -> URL {
        URL(fileURLWithPath: instance.instanceDirectory)
            .appendingPathComponent(kind.folderName, isDirectory: true)
    }

    public func list(instance: GameInstance, kind: ModrinthProjectKind) async throws -> [LocalContentItem] {
        let dir = directory(for: instance, kind: kind)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let contents = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        return contents.compactMap { url -> LocalContentItem? in
            let name = url.lastPathComponent
            let enabled: Bool
            switch kind {
            case .mod:
                if name.hasSuffix(".jar") { enabled = true }
                else if name.hasSuffix(".jar.disabled") { enabled = false }
                else { return nil }
            case .resourcepack, .shader:
                if name.hasSuffix(".zip") || name.hasSuffix(".jar") { enabled = true }
                else if name.hasSuffix(".zip.disabled") || name.hasSuffix(".jar.disabled") { enabled = false }
                else { return nil }
            case .world:
                return nil
            }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            return LocalContentItem(
                fileName: name,
                filePath: url.path,
                isEnabled: enabled,
                fileSize: size,
                kind: kind
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public func setEnabled(_ item: LocalContentItem, enabled: Bool) async throws -> LocalContentItem {
        let url = URL(fileURLWithPath: item.filePath)
        let dir = url.deletingLastPathComponent()
        let newName: String
        if enabled {
            guard item.fileName.hasSuffix(".disabled") else { return item }
            newName = String(item.fileName.dropLast(".disabled".count))
        } else {
            guard !item.fileName.hasSuffix(".disabled") else { return item }
            newName = item.fileName + ".disabled"
        }
        let destination = dir.appendingPathComponent(newName)
        if FileManager.default.fileExists(atPath: destination.path) {
            throw LocalContentError.targetExists(newName)
        }
        try FileManager.default.moveItem(at: url, to: destination)
        return LocalContentItem(
            fileName: newName,
            filePath: destination.path,
            isEnabled: enabled,
            fileSize: item.fileSize,
            kind: item.kind
        )
    }

    public func delete(_ item: LocalContentItem) async throws {
        try FileManager.default.removeItem(at: URL(fileURLWithPath: item.filePath))
    }
}

public typealias LocalModServiceImpl = LocalContentServiceImpl

public enum LocalContentError: LocalizedError {
    case targetExists(String)

    public var errorDescription: String? {
        switch self {
        case .targetExists(let name):
            return "A file named \(name) already exists."
        }
    }
}

public typealias LocalModError = LocalContentError
