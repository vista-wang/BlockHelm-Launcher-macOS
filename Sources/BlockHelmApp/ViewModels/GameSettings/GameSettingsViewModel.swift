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
    @Published public var errorMessage: String?

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public func reload() async {
        do {
            instances = try await container.instanceService.listInstances()
            if let selected, let fresh = instances.first(where: { $0.id == selected.id }) {
                self.selected = fresh
            } else {
                self.selected = instances.first
            }
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
