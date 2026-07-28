/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI
import BlockHelmDomain

struct DownloadPageView: View {
    @EnvironmentObject private var main: MainViewModel
    @Environment(\.themePalette) private var palette

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.Download.title)
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Toggle(L10n.Download.showSnapshots, isOn: $main.download.showSnapshots)
                        .toggleStyle(.checkbox)
                        .onChange(of: main.download.showSnapshots) { _ in
                            Task { await main.download.refresh(settings: main.settings) }
                        }
                    Button(L10n.Download.refresh) {
                        Task { await main.download.refresh(settings: main.settings) }
                    }
                }

                if main.download.isLoading {
                    ProgressView(L10n.Common.loading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(main.download.versions, selection: Binding(
                        get: { main.download.selectedVersion?.name },
                        set: { name in
                            main.download.selectedVersion = main.download.versions.first { $0.name == name }
                        }
                    )) { version in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(version.name).font(.body.weight(.medium))
                                Text(version.type)
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }
                            Spacer()
                            if version.isInstalled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(palette.accent)
                            }
                        }
                        .tag(version.name)
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
            .padding(20)
            .frame(minWidth: 360)

            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.Download.install)
                    .font(.title2.weight(.semibold))

                if let selected = main.download.selectedVersion {
                    LabeledContent("Minecraft", value: selected.name)
                }

                Picker(L10n.Download.loader, selection: $main.download.loader) {
                    Text(LoaderKind.vanilla.displayName).tag(LoaderKind.vanilla)
                    Text(LoaderKind.fabric.displayName).tag(LoaderKind.fabric)
                    Text(LoaderKind.quilt.displayName).tag(LoaderKind.quilt)
                        .disabled(true)
                    Text(LoaderKind.forge.displayName).tag(LoaderKind.forge)
                        .disabled(true)
                    Text(LoaderKind.neoForge.displayName).tag(LoaderKind.neoForge)
                        .disabled(true)
                }

                TextField(L10n.Download.instanceName, text: $main.download.instanceName)

                if let progress = main.download.progress {
                    ProgressView(value: progress)
                }
                if !main.download.status.isEmpty {
                    Text(main.download.status)
                        .foregroundStyle(palette.secondaryText)
                }
                if let error = main.download.errorMessage {
                    Text(error).foregroundStyle(.red)
                }

                Button {
                    Task {
                        await main.download.install(settings: main.settings)
                        await main.home.reload(settings: main.settings, accountState: main.accountState)
                        await main.gameSettings.reload()
                        await main.install.reload()
                    }
                } label: {
                    Label(
                        main.download.isInstalling ? L10n.Common.loading : L10n.Download.install,
                        systemImage: "arrow.down.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(main.download.isInstalling || main.download.selectedVersion == nil)

                Spacer()
            }
            .padding(24)
            .frame(minWidth: 280)
        }
        .task {
            if main.download.versions.isEmpty {
                await main.download.refresh(settings: main.settings)
            }
        }
    }
}
