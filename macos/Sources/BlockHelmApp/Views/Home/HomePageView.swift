/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI

struct HomePageView: View {
    @EnvironmentObject private var main: MainViewModel
    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(L10n.Page.home)
                .font(.largeTitle.weight(.bold))

            if main.home.instances.isEmpty {
                EmptyStateView(
                    title: L10n.Home.noInstance,
                    systemImage: "shippingbox",
                    description: L10n.Page.download
                )
            } else {
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker(L10n.Home.selectInstance, selection: $main.home.selectedInstanceId) {
                            ForEach(main.home.instances) { instance in
                                Text("\(instance.name) (\(instance.minecraftVersion))")
                                    .tag(Optional(instance.id))
                            }
                        }
                        .pickerStyle(.menu)

                        if let selected = main.home.selectedInstance {
                            LabeledContent("Loader", value: selected.loader.displayName)
                            LabeledContent("Version", value: selected.versionName)
                        }

                        if let progress = main.home.progress {
                            ProgressView(value: progress)
                        }
                        if !main.home.status.isEmpty {
                            Text(main.home.status)
                                .foregroundStyle(palette.secondaryText)
                        }
                        if let error = main.home.errorMessage {
                            Text(error).foregroundStyle(.red)
                        }

                        Button {
                            Task {
                                await main.home.launch(
                                    accountState: main.accountState,
                                    settings: main.settings
                                )
                            }
                        } label: {
                            Label(
                                main.home.isLaunching ? L10n.Home.launching : L10n.Home.launch,
                                systemImage: "play.fill"
                            )
                            .frame(maxWidth: 220)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(main.home.isLaunching || main.home.selectedInstance == nil)
                        .controlSize(.large)
                    }
                    .padding(8)
                }
            }

            Spacer()
        }
        .padding(28)
        .task {
            await main.home.reload(settings: main.settings, accountState: main.accountState)
        }
    }
}
