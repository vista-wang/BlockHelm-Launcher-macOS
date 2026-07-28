/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI
import BlockHelmDomain
import UniformTypeIdentifiers

struct DownloadPageView: View {
    @EnvironmentObject private var main: MainViewModel
    @Environment(\.themePalette) private var palette
    @State private var isImportingMrpack = false

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
                    Text(LoaderKind.forge.displayName).tag(LoaderKind.forge)
                    Text(LoaderKind.neoForge.displayName).tag(LoaderKind.neoForge)
                }
                .onChange(of: main.download.loader) { _ in
                    Task { await main.download.refreshLoaderVersions(settings: main.settings) }
                }
                .onChange(of: main.download.selectedVersion?.name) { _ in
                    Task { await main.download.refreshLoaderVersions(settings: main.settings) }
                }

                if main.download.loader == .forge || main.download.loader == .neoForge {
                    Picker(L10n.Download.loaderVersion, selection: $main.download.selectedLoaderVersion) {
                        ForEach(main.download.loaderVersions) { item in
                            Text(item.version).tag(Optional(item.version))
                        }
                    }
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
                .disabled(main.download.isInstalling || main.download.isImportingMrpack || main.download.selectedVersion == nil)

                Button {
                    isImportingMrpack = true
                } label: {
                    Label(
                        main.download.isImportingMrpack ? L10n.Common.loading : L10n.Download.importMrpack,
                        systemImage: "shippingbox.fill"
                    )
                }
                .disabled(main.download.isInstalling || main.download.isImportingMrpack)

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
        .fileImporter(
            isPresented: $isImportingMrpack,
            allowedContentTypes: [UTType(filenameExtension: "mrpack") ?? .zip, .zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                Task {
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    await main.download.importMrpack(from: url, settings: main.settings)
                    await main.home.reload(settings: main.settings, accountState: main.accountState)
                    await main.gameSettings.reload()
                    await main.install.reload()
                }
            case .failure(let error):
                main.download.errorMessage = error.localizedDescription
            }
        }
    }
}
