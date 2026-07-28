/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import SwiftUI
import BlockHelmDomain

public enum AppPage: String, CaseIterable, Identifiable, Hashable {
    case account
    case home
    case multiplayer
    case download
    case install
    case gameSettings
    case resources
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .account: return L10n.Page.account
        case .home: return L10n.Page.home
        case .multiplayer: return L10n.Page.multiplayer
        case .download: return L10n.Page.download
        case .install: return L10n.Page.install
        case .gameSettings: return L10n.Page.gameSettings
        case .resources: return L10n.Page.resources
        case .settings: return L10n.Page.settings
        }
    }

    public var systemImage: String {
        switch self {
        case .account: return "person.crop.circle"
        case .home: return "house.fill"
        case .multiplayer: return "person.2.fill"
        case .download: return "arrow.down.circle"
        case .install: return "list.bullet.rectangle"
        case .gameSettings: return "shippingbox"
        case .resources: return "square.stack.3d.up"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
public final class MainViewModel: ObservableObject {
    @Published public var currentPage: AppPage = .home
    @Published public var settings: LauncherSettings = LauncherSettings()
    @Published public var accountState: LauncherAccountState = LauncherAccountState()
    @Published public var statusMessage: String = ""
    @Published public var isBusy: Bool = false

    public let container: AppContainer
    public let home: HomeViewModel
    public let download: DownloadViewModel
    public let install: InstallViewModel
    public let account: AccountViewModel
    public let gameSettings: GameSettingsViewModel
    public let settingsPage: SettingsViewModel

    public init(container: AppContainer) {
        self.container = container
        self.home = HomeViewModel(container: container)
        self.download = DownloadViewModel(container: container)
        self.install = InstallViewModel(container: container)
        self.account = AccountViewModel(container: container)
        self.gameSettings = GameSettingsViewModel(container: container)
        self.settingsPage = SettingsViewModel(container: container)
    }

    public func bootstrap() async {
        do {
            settings = try await container.settingsService.load()
            accountState = try await container.accountStore.load()
            applyLanguage(settings.launcherLanguage)
            await home.reload(settings: settings, accountState: accountState)
            await gameSettings.reload()
            await account.reload()
            await settingsPage.reload()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func persistSettings() async {
        do {
            settings.revision += 1
            try await container.settingsService.save(settings)
            applyLanguage(settings.launcherLanguage)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func applyLanguage(_ code: String) {
        // Persist preference; full UI refresh typically needs relaunch for Bundle localization.
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
    }
}
