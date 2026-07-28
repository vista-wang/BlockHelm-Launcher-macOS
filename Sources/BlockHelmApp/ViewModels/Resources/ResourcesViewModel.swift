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
    @Published public var query: String = ""
    @Published public var projects: [ModrinthProject] = []
    @Published public var isSearching = false
    @Published public var installingProjectId: String?
    @Published public var status: String = ""
    @Published public var errorMessage: String?

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public var selectedInstance: GameInstance? {
        instances.first { $0.id == selectedInstanceId }
    }

    public func reloadInstances() async {
        do {
            instances = try await container.instanceService.listInstances()
                .filter { $0.loader != .vanilla }
            if selectedInstanceId == nil {
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
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            projects = try await container.modrinth.searchMods(
                query: query,
                minecraftVersion: instance.minecraftVersion,
                loader: instance.loader
            )
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
            let path = try await container.modrinth.installLatestCompatible(
                project: project,
                instance: instance
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.status = progress.message
                }
            }
            status = L10n.Resources.installed(URL(fileURLWithPath: path).lastPathComponent)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
