/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI

struct MultiplayerPageView: View {
    @EnvironmentObject private var main: MainViewModel
    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.Page.multiplayer)
                    .font(.title2.weight(.semibold))
                Spacer()
                if main.multiplayer.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Button(L10n.Multiplayer.stop) {
                        Task { await main.multiplayer.stop() }
                    }
                } else {
                    Button(L10n.Multiplayer.scan) {
                        Task { await main.multiplayer.start() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Text(L10n.Multiplayer.hint)
                .foregroundStyle(palette.secondaryText)

            GroupBox(L10n.Multiplayer.terracottaTitle) {
                Text(L10n.Multiplayer.terracottaUnavailable)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if main.multiplayer.worlds.isEmpty {
                EmptyStateView(title: L10n.Page.multiplayer, systemImage: "person.2.fill")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(main.multiplayer.worlds) { world in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(world.motd).font(.headline)
                            Text(world.joinAddress)
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                        Button(L10n.Multiplayer.copy) {
                            main.multiplayer.copyAddress(world)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            if !main.multiplayer.status.isEmpty {
                Text(main.multiplayer.status)
                    .foregroundStyle(palette.secondaryText)
            }
            if let error = main.multiplayer.errorMessage {
                Text(error).foregroundStyle(.red)
            }
        }
        .padding(20)
        .task {
            await main.multiplayer.start()
        }
        .onDisappear {
            Task { await main.multiplayer.stop() }
        }
    }
}
