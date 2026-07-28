/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmDomain

public final class DefaultGameInstanceService: GameInstanceService, @unchecked Sendable {
    private let repository: GameInstanceRepository
    private let pathProvider: LauncherPathProviding
    private let settingsService: SettingsService

    public init(
        repository: GameInstanceRepository,
        pathProvider: LauncherPathProviding,
        settingsService: SettingsService
    ) {
        self.repository = repository
        self.pathProvider = pathProvider
        self.settingsService = settingsService
    }

    public func listInstances() async throws -> [GameInstance] {
        try await repository.list().sorted { $0.updatedAt > $1.updatedAt }
    }

    public func createInstance(
        name: String,
        minecraftVersion: String,
        versionType: String,
        loader: LoaderKind,
        loaderVersion: String?,
        settings: LauncherSettings
    ) async throws -> GameInstance {
        let versionName: String
        switch loader {
        case .vanilla:
            versionName = minecraftVersion
        case .fabric:
            versionName = "fabric-loader-\(loaderVersion ?? "latest")-\(minecraftVersion)"
        case .quilt:
            versionName = "quilt-loader-\(loaderVersion ?? "latest")-\(minecraftVersion)"
        case .forge:
            versionName = "\(minecraftVersion)-forge-\(loaderVersion ?? "latest")"
        case .neoForge:
            versionName = "neoforge-\(loaderVersion ?? "latest")"
        }

        let versionDir = pathProvider.versionDirectory(versionName: versionName)
        try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true)

        var instance = GameInstance(
            name: name.isEmpty ? versionName : name,
            minecraftVersion: minecraftVersion,
            loader: loader,
            loaderVersion: loaderVersion,
            versionName: versionName,
            versionType: versionType,
            instanceDirectory: versionDir.path,
            backupDirectory: versionDir.appendingPathComponent("backups", isDirectory: true).path,
            memorySettingsMode: settings.defaultMemorySettingsMode,
            memoryMb: settings.defaultMemoryMb,
            preLaunchCommand: settings.defaultPreLaunchCommand,
            waitForPreLaunchCommand: settings.defaultWaitForPreLaunchCommand,
            postExitCommand: settings.defaultPostExitCommand,
            jvmArguments: settings.defaultJvmArguments,
            gameArguments: settings.defaultGameArguments,
            checkFilesBeforeLaunch: settings.defaultCheckFilesBeforeLaunch,
            autoRepairMissingFiles: settings.defaultAutoRepairMissingFiles,
            minimizeLauncherAfterLaunch: settings.defaultMinimizeLauncherAfterLaunch,
            launchFullScreen: settings.defaultLaunchFullScreen,
            autoJoinServerAddress: settings.defaultAutoJoinServerAddress
        )
        instance.updatedAt = Date()
        try await repository.save(instance)
        return instance
    }

    public func updateInstance(_ instance: GameInstance) async throws {
        var updated = instance
        updated.updatedAt = Date()
        try await repository.save(updated)
    }

    public func deleteInstance(_ instance: GameInstance) async throws {
        try await repository.delete(versionName: instance.versionName)
    }

    public func setDefaultInstance(id: String?, settings: inout LauncherSettings) async throws {
        settings.defaultInstanceId = id
        settings.revision += 1
        try await settingsService.save(settings)
    }
}

public final class DefaultOfflineAccountService: OfflineAccountService, Sendable {
    public init() {}

    public func createOfflineAccount(
        displayName: String,
        mode: OfflineUuidGenerationMode,
        manualUuid: String?
    ) -> LauncherAccountRecord {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? LauncherDefaults.defaultOfflineUsername : trimmed
        let uuid: String
        switch mode {
        case .standard:
            uuid = OfflineUuid.standard(from: name)
        case .random:
            uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        case .manual:
            uuid = (manualUuid ?? "").replacingOccurrences(of: "-", with: "").lowercased()
        }
        return LauncherAccountRecord(
            displayName: name,
            kind: .offline,
            uuid: uuid,
            offlineUuidGenerationMode: mode,
            isOffline: true
        )
    }
}

@MainActor
public final class InMemoryInstallTaskQueue: InstallTaskQueue {
    public private(set) var tasks: [InstallTask] = []

    public init() {}

    public func enqueue(_ task: InstallTask) {
        tasks.insert(task, at: 0)
    }

    public func update(_ task: InstallTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.insert(task, at: 0)
        }
    }
}
