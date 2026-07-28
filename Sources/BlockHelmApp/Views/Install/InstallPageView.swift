/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI

struct InstallPageView: View {
    @EnvironmentObject private var main: MainViewModel
    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.Page.install)
                .font(.largeTitle.weight(.bold))

            if main.install.tasks.isEmpty {
                EmptyStateView(
                    title: L10n.Page.install,
                    systemImage: "list.bullet.rectangle",
                    description: L10n.Download.title
                )
            } else {
                List(main.install.tasks) { task in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(task.title).font(.headline)
                            Spacer()
                            Text(task.state.rawValue)
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                        if !task.detail.isEmpty {
                            Text(task.detail).foregroundStyle(palette.secondaryText)
                        }
                        if task.state == .running {
                            ProgressView(value: task.progress)
                        }
                        if let error = task.errorMessage {
                            Text(error).foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(28)
        .task { await main.install.reload() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            Task { await main.install.reload() }
        }
    }
}
