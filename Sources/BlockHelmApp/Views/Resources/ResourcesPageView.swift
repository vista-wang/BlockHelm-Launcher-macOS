/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI
import BlockHelmDomain

struct ResourcesPageView: View {
    @EnvironmentObject private var main: MainViewModel
    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.Page.resources)
                    .font(.title2.weight(.semibold))
                Spacer()
                Picker(L10n.Resources.source, selection: $main.resources.source) {
                    Text(L10n.Resources.modrinth).tag(ResourceCatalogSource.modrinth)
                    Text(L10n.Resources.curseForge).tag(ResourceCatalogSource.curseForge)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                .onChange(of: main.resources.source) { _ in
                    main.resources.projects = []
                    main.resources.errorMessage = nil
                }
            }

            HStack {
                Picker(L10n.Resources.kind, selection: $main.resources.kind) {
                    Text(L10n.Resources.mods).tag(ModrinthProjectKind.mod)
                    Text(L10n.Resources.resourcePacks).tag(ModrinthProjectKind.resourcepack)
                    Text(L10n.Resources.shaders).tag(ModrinthProjectKind.shader)
                    Text(L10n.Resources.worlds).tag(ModrinthProjectKind.world)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 520)
                .onChange(of: main.resources.kind) { _ in
                    Task {
                        await main.resources.reloadInstances()
                        main.resources.projects = []
                    }
                }
            }

            HStack {
                Picker(L10n.Resources.instance, selection: $main.resources.selectedInstanceId) {
                    ForEach(main.resources.instances) { instance in
                        Text("\(instance.name) (\(instance.loader.displayName) \(instance.minecraftVersion))")
                            .tag(Optional(instance.id))
                    }
                }
                .frame(maxWidth: 360)

                if main.resources.kind == .mod {
                    Toggle(L10n.Resources.installDeps, isOn: $main.resources.installDependencies)
                        .toggleStyle(.checkbox)
                }
            }

            if main.resources.source == .curseForge, !main.resources.curseForgeConfigured {
                Text(L10n.Resources.curseForgeKeyMissing)
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            HStack {
                TextField(L10n.Resources.searchPlaceholder, text: $main.resources.query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await main.resources.search() }
                    }
                Button(L10n.Resources.search) {
                    Task { await main.resources.search() }
                }
                .disabled(main.resources.isSearching || main.resources.selectedInstance == nil)
            }

            if main.resources.isSearching {
                ProgressView(L10n.Common.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if main.resources.projects.isEmpty {
                EmptyStateView(title: L10n.Page.resources, systemImage: "square.stack.3d.up")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(main.resources.projects) { project in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.title).font(.headline)
                            Text(project.description)
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(2)
                            Text(L10n.Resources.downloads(project.downloads))
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                        Button(L10n.Resources.install) {
                            Task {
                                await main.resources.install(project)
                                await main.gameSettings.reload()
                            }
                        }
                        .disabled(main.resources.installingProjectId != nil)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            if !main.resources.status.isEmpty {
                Text(main.resources.status)
                    .foregroundStyle(palette.secondaryText)
            }
            if let error = main.resources.errorMessage {
                Text(error).foregroundStyle(.red)
            }
        }
        .padding(20)
        .task {
            await main.resources.reloadInstances()
        }
    }
}
