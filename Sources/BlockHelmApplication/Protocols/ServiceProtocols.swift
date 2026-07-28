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
    func searchMods(
        query: String,
        minecraftVersion: String,
        loader: LoaderKind
    ) async throws -> [ModrinthProject]

    func installLatestCompatible(
        project: ModrinthProject,
        instance: GameInstance,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> String
}

public protocol LocalModService: Sendable {
    func listMods(instance: GameInstance) async throws -> [LocalModInfo]
    func setEnabled(_ mod: LocalModInfo, enabled: Bool) async throws -> LocalModInfo
    func delete(_ mod: LocalModInfo) async throws
    func modsDirectory(for instance: GameInstance) -> URL
}

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
