/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmDomain

public protocol LauncherPathProviding: Sendable {
    var dataDirectory: URL { get }
    var minecraftDirectory: URL { get }
    var accountDataDirectory: URL { get }
    var settingsFileURL: URL { get }
    var accountStateFileURL: URL { get }
    func instanceSettingsURL(versionName: String) -> URL
    func versionDirectory(versionName: String) -> URL
}

public protocol SettingsService: Sendable {
    func load() async throws -> LauncherSettings
    func save(_ settings: LauncherSettings) async throws
}

public protocol AccountStore: Sendable {
    func load() async throws -> LauncherAccountState
    func save(_ state: LauncherAccountState) async throws
}

public protocol GameInstanceRepository: Sendable {
    func list() async throws -> [GameInstance]
    func load(versionName: String) async throws -> GameInstance?
    func save(_ instance: GameInstance) async throws
    func delete(versionName: String) async throws
}

public protocol GameInstanceService: Sendable {
    func listInstances() async throws -> [GameInstance]
    func createInstance(
        name: String,
        minecraftVersion: String,
        versionType: String,
        loader: LoaderKind,
        loaderVersion: String?,
        settings: LauncherSettings
    ) async throws -> GameInstance
    func updateInstance(_ instance: GameInstance) async throws
    func deleteInstance(_ instance: GameInstance) async throws
    func setDefaultInstance(id: String?, settings: inout LauncherSettings) async throws
}

public protocol GameVersionService: Sendable {
    func listVersions(
        source: DownloadSourcePreference,
        includeSnapshots: Bool
    ) async throws -> [MinecraftVersionInfo]
}

public protocol GameInstallService: Sendable {
    func installVanilla(
        version: MinecraftVersionInfo,
        instanceName: String,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance

    func installFabric(
        minecraftVersion: String,
        loaderVersion: String?,
        instanceName: String,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance

    func installQuilt(
        minecraftVersion: String,
        loaderVersion: String?,
        instanceName: String,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance

    func installForge(
        minecraftVersion: String,
        loaderVersion: String?,
        instanceName: String,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance

    func installNeoForge(
        minecraftVersion: String,
        loaderVersion: String?,
        instanceName: String,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance
}

public protocol LoaderCatalogService: Sendable {
    func listForgeVersions(minecraftVersion: String, source: DownloadSourcePreference) async throws -> [LoaderVersionInfo]
    func listNeoForgeVersions(minecraftVersion: String, source: DownloadSourcePreference) async throws -> [LoaderVersionInfo]
}

public protocol ModrinthService: Sendable {
    func searchProjects(
        query: String,
        kind: ModrinthProjectKind,
        minecraftVersion: String,
        loader: LoaderKind
    ) async throws -> [ModrinthProject]

    func installLatestCompatible(
        project: ModrinthProject,
        instance: GameInstance,
        installDependencies: Bool,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> [String]
}

public protocol CurseForgeService: Sendable {
    var isConfigured: Bool { get }
    func searchProjects(
        query: String,
        kind: ModrinthProjectKind,
        minecraftVersion: String,
        loader: LoaderKind
    ) async throws -> [ModrinthProject]
    func installLatestCompatible(
        project: ModrinthProject,
        instance: GameInstance,
        installDependencies: Bool,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> [String]
}

public protocol ModpackImportService: Sendable {
    func importMrpack(
        archiveURL: URL,
        instanceName: String?,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance
}

public protocol LocalSaveService: Sendable {
    func listSaves(instance: GameInstance) async throws -> [LocalSave]
    func importFromZip(instance: GameInstance, archiveURL: URL) async throws -> LocalSave
    func delete(_ save: LocalSave) async throws
}

public protocol LocalContentService: Sendable {
    func list(instance: GameInstance, kind: ModrinthProjectKind) async throws -> [LocalContentItem]
    func setEnabled(_ item: LocalContentItem, enabled: Bool) async throws -> LocalContentItem
    func delete(_ item: LocalContentItem) async throws
    func directory(for instance: GameInstance, kind: ModrinthProjectKind) -> URL
}

public protocol LanWorldDiscoveryService: Sendable {
    func start() async
    func stop() async
    func snapshot() async -> [LanWorldAdvertisement]
}

public protocol LaunchIntegrityService: Sendable {
    func validate(instance: GameInstance, settings: LauncherSettings) async throws
}

/// Back-compat alias used by earlier App wiring.
public typealias LocalModService = LocalContentService

public protocol LaunchService: Sendable {
    func launch(
        instance: GameInstance,
        account: LaunchAccount,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> Int32
}

public protocol JavaRuntimeDiscoveryService: Sendable {
    func discover() async -> [JavaRuntimeInfo]
    func resolveExecutable(settings: LauncherSettings, instance: GameInstance?) async -> JavaRuntimeInfo?
}

public protocol OfflineAccountService: Sendable {
    func createOfflineAccount(displayName: String, mode: OfflineUuidGenerationMode, manualUuid: String?) -> LauncherAccountRecord
}

public protocol MicrosoftAccountService: Sendable {
    /// Starts interactive OAuth. On macOS this uses AuthenticationServices.
    func signIn() async throws -> LauncherAccountRecord
    /// Builds a launch session for a previously signed-in Microsoft account.
    func launchAccount(for account: LauncherAccountRecord) async throws -> LaunchAccount
}

@MainActor
public protocol InstallTaskQueue: AnyObject {
    var tasks: [InstallTask] { get }
    func enqueue(_ task: InstallTask)
    func update(_ task: InstallTask)
}
