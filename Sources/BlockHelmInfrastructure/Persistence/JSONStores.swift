/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmApplication
import BlockHelmDomain

enum JSONFileStore {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(value)
        let temp = url.appendingPathExtension("tmp")
        try data.write(to: temp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: temp, to: url)
    }
}

public final class JSONSettingsService: SettingsService, @unchecked Sendable {
    private let pathProvider: LauncherPathProviding
    private let queue = DispatchQueue(label: "com.blockhelm.settings")

    public init(pathProvider: LauncherPathProviding) {
        self.pathProvider = pathProvider
    }

    public func load() async throws -> LauncherSettings {
        if let existing = try JSONFileStore.read(LauncherSettings.self, from: pathProvider.settingsFileURL) {
            return normalize(existing)
        }
        let defaults = LauncherSettings(
            dataDirectory: pathProvider.dataDirectory.path,
            minecraftDirectory: pathProvider.minecraftDirectory.path
        )
        try await save(defaults)
        return defaults
    }

    public func save(_ settings: LauncherSettings) async throws {
        let normalized = normalize(settings)
        let url = pathProvider.settingsFileURL
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try JSONFileStore.write(normalized, to: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func normalize(_ settings: LauncherSettings) -> LauncherSettings {
        var copy = settings
        if copy.dataDirectory.isEmpty {
            copy.dataDirectory = pathProvider.dataDirectory.path
        }
        if copy.minecraftDirectory.isEmpty {
            copy.minecraftDirectory = pathProvider.minecraftDirectory.path
        }
        copy.launcherBackgroundOpacityPercent = min(100, max(0, copy.launcherBackgroundOpacityPercent))
        copy.maximumDownloadConcurrency = min(128, max(1, copy.maximumDownloadConcurrency))
        copy.defaultMemoryMb = min(32768, max(1024, copy.defaultMemoryMb))
        return copy
    }
}

public final class JSONAccountStore: AccountStore, @unchecked Sendable {
    private let pathProvider: LauncherPathProviding

    public init(pathProvider: LauncherPathProviding) {
        self.pathProvider = pathProvider
    }

    public func load() async throws -> LauncherAccountState {
        if let existing = try JSONFileStore.read(LauncherAccountState.self, from: pathProvider.accountStateFileURL) {
            return existing
        }
        let offline = DefaultOfflineAccountService().createOfflineAccount(
            displayName: LauncherDefaults.defaultOfflineUsername,
            mode: .standard,
            manualUuid: nil
        )
        let state = LauncherAccountState(
            offlineUsername: offline.displayName,
            selectedAccountId: offline.id,
            accountsInitialized: true,
            accounts: [offline]
        )
        try await save(state)
        return state
    }

    public func save(_ state: LauncherAccountState) async throws {
        try JSONFileStore.write(state, to: pathProvider.accountStateFileURL)
    }
}

public final class JSONGameInstanceRepository: GameInstanceRepository, @unchecked Sendable {
    private let pathProvider: LauncherPathProviding

    public init(pathProvider: LauncherPathProviding) {
        self.pathProvider = pathProvider
    }

    public func list() async throws -> [GameInstance] {
        let versionsRoot = pathProvider.minecraftDirectory.appendingPathComponent("versions", isDirectory: true)
        guard FileManager.default.fileExists(atPath: versionsRoot.path) else { return [] }
        let contents = try FileManager.default.contentsOfDirectory(
            at: versionsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var instances: [GameInstance] = []
        for dir in contents {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            if let instance = try await load(versionName: dir.lastPathComponent) {
                instances.append(instance)
            }
        }
        return instances
    }

    public func load(versionName: String) async throws -> GameInstance? {
        let url = pathProvider.instanceSettingsURL(versionName: versionName)
        if let instance = try JSONFileStore.read(GameInstance.self, from: url) {
            return instance
        }
        // Discover bare installed versions without BHL metadata.
        let versionJSON = pathProvider.versionDirectory(versionName: versionName)
            .appendingPathComponent("\(versionName).json")
        guard FileManager.default.fileExists(atPath: versionJSON.path) else { return nil }
        return GameInstance(
            name: versionName,
            minecraftVersion: versionName,
            loader: .vanilla,
            versionName: versionName,
            versionType: "release",
            instanceDirectory: pathProvider.versionDirectory(versionName: versionName).path
        )
    }

    public func save(_ instance: GameInstance) async throws {
        let url = pathProvider.instanceSettingsURL(versionName: instance.versionName)
        try JSONFileStore.write(instance, to: url)
    }

    public func delete(versionName: String) async throws {
        let dir = pathProvider.versionDirectory(versionName: versionName)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.trashItem(at: dir, resultingItemURL: nil)
        }
    }
}
