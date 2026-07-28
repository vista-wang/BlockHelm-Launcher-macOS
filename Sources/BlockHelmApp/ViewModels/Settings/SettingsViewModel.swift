/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmDomain

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var draft = LauncherSettings()
    @Published public var javaRuntimes: [JavaRuntimeInfo] = []
    @Published public var errorMessage: String?
    @Published public var savedMessage: String?

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public func reload() async {
        do {
            draft = try await container.settingsService.load()
            javaRuntimes = await container.javaDiscovery.discover()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func save() async -> LauncherSettings? {
        do {
            draft.revision += 1
            try await container.settingsService.save(draft)
            savedMessage = L10n.Settings.save
            return draft
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
