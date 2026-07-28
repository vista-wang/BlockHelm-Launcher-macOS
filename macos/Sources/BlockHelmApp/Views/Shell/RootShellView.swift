/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI

struct RootShellView: View {
    @EnvironmentObject private var main: MainViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = ThemePalette.resolve(settings: main.settings, colorScheme: colorScheme)
        NavigationSplitView {
            ShellSidebarView(selection: $main.currentPage)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.background)
        }
        .environment(\.themePalette, palette)
        .tint(palette.accent)
        .preferredColorScheme(preferredScheme)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch main.currentPage {
        case .home:
            HomePageView()
        case .download:
            DownloadPageView()
        case .install:
            InstallPageView()
        case .account:
            AccountPageView()
        case .gameSettings:
            GameSettingsPageView()
        case .settings:
            SettingsPageView()
        case .resources:
            PlaceholderPageView(title: L10n.Page.resources)
        case .multiplayer:
            PlaceholderPageView(title: L10n.Page.multiplayer)
        }
    }

    private var preferredScheme: ColorScheme? {
        if main.settings.themeFollowSystem { return nil }
        return main.settings.theme.lowercased() == "light" ? .light : .dark
    }
}

struct ShellSidebarView: View {
    @Binding var selection: AppPage
    @Environment(\.themePalette) private var palette

    private let primary: [AppPage] = [
        .account, .home, .multiplayer, .download, .install, .gameSettings, .resources, .settings
    ]

    var body: some View {
        List(selection: $selection) {
            Section {
                Label(L10n.Common.appName, systemImage: "cube.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(primary) { page in
                    Label(page.title, systemImage: page.systemImage)
                        .tag(page)
                }
            }
        }
        .listStyle(.sidebar)
        .background(palette.sidebar)
    }
}

struct PlaceholderPageView: View {
    let title: String
    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.largeTitle.weight(.bold))
            Text(L10n.Common.comingSoon)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
