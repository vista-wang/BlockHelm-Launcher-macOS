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
                Picker(L10n.Resources.instance, selection: $main.resources.selectedInstanceId) {
                    ForEach(main.resources.instances) { instance in
                        Text("\(instance.name) (\(instance.loader.displayName) \(instance.minecraftVersion))")
                            .tag(Optional(instance.id))
                    }
                }
                .frame(maxWidth: 360)
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
                            Task { await main.resources.install(project) }
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
