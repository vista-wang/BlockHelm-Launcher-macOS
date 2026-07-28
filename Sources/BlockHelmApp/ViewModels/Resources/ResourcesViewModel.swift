/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmDomain

@MainActor
public final class ResourcesViewModel: ObservableObject {
    @Published public var instances: [GameInstance] = []
    @Published public var selectedInstanceId: String?
    @Published public var source: ResourceCatalogSource = .modrinth
    @Published public var kind: ModrinthProjectKind = .mod
    @Published public var query: String = ""
    @Published public var projects: [ModrinthProject] = []
    @Published public var isSearching = false
    @Published public var installingProjectId: String?
    @Published public var installDependencies = true
    @Published public var status: String = ""
    @Published public var errorMessage: String?

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public var selectedInstance: GameInstance? {
        instances.first { $0.id == selectedInstanceId }
    }

    public var curseForgeConfigured: Bool {
        container.curseForge.isConfigured
    }

    public func reloadInstances() async {
        do {
            let all = try await container.instanceService.listInstances()
            switch kind {
            case .mod:
                instances = all.filter { $0.loader != .vanilla }
            case .resourcepack, .shader, .world:
                instances = all
            }
            if selectedInstanceId == nil || !instances.contains(where: { $0.id == selectedInstanceId }) {
                selectedInstanceId = instances.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func search() async {
        guard let instance = selectedInstance else {
            errorMessage = L10n.Resources.needInstance
            return
        }
        if source == .curseForge, !curseForgeConfigured {
            errorMessage = L10n.Resources.curseForgeKeyMissing
            projects = []
            return
        }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            switch source {
            case .modrinth:
                projects = try await container.modrinth.searchProjects(
                    query: query,
                    kind: kind,
                    minecraftVersion: instance.minecraftVersion,
                    loader: instance.loader
                )
            case .curseForge:
                projects = try await container.curseForge.searchProjects(
                    query: query,
                    kind: kind,
                    minecraftVersion: instance.minecraftVersion,
                    loader: instance.loader
                )
            }
            status = L10n.Resources.resultCount(projects.count)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func install(_ project: ModrinthProject) async {
        guard let instance = selectedInstance else { return }
        installingProjectId = project.projectId
        errorMessage = nil
        defer { installingProjectId = nil }
        do {
            let paths: [String]
            switch source {
            case .modrinth:
                paths = try await container.modrinth.installLatestCompatible(
                    project: project,
                    instance: instance,
                    installDependencies: installDependencies && kind == .mod
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.status = progress.message
                    }
                }
            case .curseForge:
                paths = try await container.curseForge.installLatestCompatible(
                    project: project,
                    instance: instance,
                    installDependencies: installDependencies && kind == .mod
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.status = progress.message
                    }
                }
            }
            let names = paths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
            status = L10n.Resources.installed(names)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
