/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmApplication
import BlockHelmDomain

public final class LocalModServiceImpl: LocalModService, @unchecked Sendable {
    public init() {}

    public func modsDirectory(for instance: GameInstance) -> URL {
        URL(fileURLWithPath: instance.instanceDirectory)
            .appendingPathComponent("mods", isDirectory: true)
    }

    public func listMods(instance: GameInstance) async throws -> [LocalModInfo] {
        let dir = modsDirectory(for: instance)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let contents = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        return contents.compactMap { url -> LocalModInfo? in
            let name = url.lastPathComponent
            let enabled: Bool
            if name.hasSuffix(".jar") {
                enabled = true
            } else if name.hasSuffix(".jar.disabled") {
                enabled = false
            } else {
                return nil
            }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            return LocalModInfo(
                fileName: name,
                filePath: url.path,
                isEnabled: enabled,
                fileSize: size
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public func setEnabled(_ mod: LocalModInfo, enabled: Bool) async throws -> LocalModInfo {
        let url = URL(fileURLWithPath: mod.filePath)
        let dir = url.deletingLastPathComponent()
        let newName: String
        if enabled {
            guard mod.fileName.hasSuffix(".jar.disabled") else { return mod }
            newName = String(mod.fileName.dropLast(".disabled".count))
        } else {
            guard mod.fileName.hasSuffix(".jar"), !mod.fileName.hasSuffix(".jar.disabled") else { return mod }
            newName = mod.fileName + ".disabled"
        }
        let destination = dir.appendingPathComponent(newName)
        if FileManager.default.fileExists(atPath: destination.path) {
            throw LocalModError.targetExists(newName)
        }
        try FileManager.default.moveItem(at: url, to: destination)
        return LocalModInfo(
            fileName: newName,
            filePath: destination.path,
            isEnabled: enabled,
            fileSize: mod.fileSize
        )
    }

    public func delete(_ mod: LocalModInfo) async throws {
        try FileManager.default.removeItem(at: URL(fileURLWithPath: mod.filePath))
    }
}

public enum LocalModError: LocalizedError {
    case targetExists(String)

    public var errorDescription: String? {
        switch self {
        case .targetExists(let name):
            return "A file named \(name) already exists."
        }
    }
}
