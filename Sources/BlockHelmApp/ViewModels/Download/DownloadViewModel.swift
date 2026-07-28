/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmDomain

@MainActor
public final class DownloadViewModel: ObservableObject {
    @Published public var versions: [MinecraftVersionInfo] = []
    @Published public var selectedVersion: MinecraftVersionInfo?
    @Published public var loader: LoaderKind = .vanilla
    @Published public var loaderVersions: [LoaderVersionInfo] = []
    @Published public var selectedLoaderVersion: String?
    @Published public var instanceName: String = ""
    @Published public var showSnapshots = false
    @Published public var isLoading = false
    @Published public var isInstalling = false
    @Published public var status: String = ""
    @Published public var progress: Double?
    @Published public var errorMessage: String?

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public func refresh(settings: LauncherSettings) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            versions = try await container.versionService.listVersions(
                source: settings.downloadSourcePreference,
                includeSnapshots: showSnapshots
            )
            if selectedVersion == nil {
                selectedVersion = versions.first
            }
            await refreshLoaderVersions(settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func refreshLoaderVersions(settings: LauncherSettings) async {
        guard let mc = selectedVersion?.name else {
            loaderVersions = []
            selectedLoaderVersion = nil
            return
        }
        do {
            switch loader {
            case .forge:
                loaderVersions = try await container.loaderCatalog.listForgeVersions(
                    minecraftVersion: mc,
                    source: settings.downloadSourcePreference
                )
            case .neoForge:
                loaderVersions = try await container.loaderCatalog.listNeoForgeVersions(
                    minecraftVersion: mc,
                    source: settings.downloadSourcePreference
                )
            default:
                loaderVersions = []
            }
            selectedLoaderVersion = loaderVersions.first?.version
        } catch {
            loaderVersions = []
            selectedLoaderVersion = nil
            if loader == .forge || loader == .neoForge {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func install(settings: LauncherSettings) async {
        guard let version = selectedVersion else { return }
        isInstalling = true
        errorMessage = nil
        defer { isInstalling = false }

        var task = InstallTask(title: "\(loader.displayName) \(version.name)", state: .running)
        container.installTasks.enqueue(task)

        do {
            let instance: GameInstance
            switch loader {
            case .vanilla:
                instance = try await container.installService.installVanilla(
                    version: version,
                    instanceName: instanceName,
                    settings: settings
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.status = progress.message
                        self?.progress = progress.percent
                    }
                }
            case .fabric:
                instance = try await container.installService.installFabric(
                    minecraftVersion: version.name,
                    loaderVersion: nil,
                    instanceName: instanceName,
                    settings: settings
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.status = progress.message
                        self?.progress = progress.percent
                    }
                }
            case .quilt:
                instance = try await container.installService.installQuilt(
                    minecraftVersion: version.name,
                    loaderVersion: nil,
                    instanceName: instanceName,
                    settings: settings
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.status = progress.message
                        self?.progress = progress.percent
                    }
                }
            case .forge:
                instance = try await container.installService.installForge(
                    minecraftVersion: version.name,
                    loaderVersion: selectedLoaderVersion,
                    instanceName: instanceName,
                    settings: settings
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.status = progress.message
                        self?.progress = progress.percent
                    }
                }
            case .neoForge:
                instance = try await container.installService.installNeoForge(
                    minecraftVersion: version.name,
                    loaderVersion: selectedLoaderVersion,
                    instanceName: instanceName,
                    settings: settings
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.status = progress.message
                        self?.progress = progress.percent
                    }
                }
            }
            task.state = .completed
            task.progress = 1
            task.detail = instance.name
            container.installTasks.update(task)
            status = "Installed \(instance.name)"
        } catch {
            task.state = .failed
            task.errorMessage = error.localizedDescription
            container.installTasks.update(task)
            errorMessage = error.localizedDescription
        }
    }
}
