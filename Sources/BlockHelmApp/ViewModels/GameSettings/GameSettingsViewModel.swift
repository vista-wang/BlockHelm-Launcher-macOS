/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmDomain

@MainActor
public final class GameSettingsViewModel: ObservableObject {
    @Published public var instances: [GameInstance] = []
    @Published public var selected: GameInstance?
    @Published public var contentKind: ModrinthProjectKind = .mod
    @Published public var contentItems: [LocalContentItem] = []
    @Published public var errorMessage: String?
    @Published public var statusMessage: String?

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public var mods: [LocalContentItem] { contentItems.filter { $0.kind == .mod } }

    public func reload() async {
        do {
            instances = try await container.instanceService.listInstances()
            if let selected, let fresh = instances.first(where: { $0.id == selected.id }) {
                self.selected = fresh
            } else {
                self.selected = instances.first
            }
            await reloadContent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func select(_ instance: GameInstance) async {
        selected = instance
        await reloadContent()
    }

    public func reloadContent() async {
        guard let selected else {
            contentItems = []
            return
        }
        do {
            contentItems = try await container.localContent.list(instance: selected, kind: contentKind)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func reloadMods() async {
        contentKind = .mod
        await reloadContent()
    }

    public func toggleMod(_ mod: LocalContentItem) async {
        await toggleContent(mod)
    }

    public func deleteMod(_ mod: LocalContentItem) async {
        await deleteContent(mod)
    }

    public func toggleContent(_ item: LocalContentItem) async {
        do {
            _ = try await container.localContent.setEnabled(item, enabled: !item.isEnabled)
            await reloadContent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteContent(_ item: LocalContentItem) async {
        do {
            try await container.localContent.delete(item)
            await reloadContent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveSelected() async {
        guard var selected else { return }
        selected.updatedAt = Date()
        do {
            try await container.instanceService.updateInstance(selected)
            self.selected = selected
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteSelected() async {
        guard let selected else { return }
        do {
            try await container.instanceService.deleteInstance(selected)
            self.selected = nil
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
