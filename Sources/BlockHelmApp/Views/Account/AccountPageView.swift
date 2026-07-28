/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI
import BlockHelmDomain

struct AccountPageView: View {
    @EnvironmentObject private var main: MainViewModel
    @Environment(\.themePalette) private var palette

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.Page.account)
                    .font(.title2.weight(.semibold))

                List(main.account.state.accounts, selection: Binding(
                    get: { main.account.state.selectedAccountId },
                    set: { id in
                        if let id, let account = main.account.state.accounts.first(where: { $0.id == id }) {
                            Task { await main.account.select(account) }
                        }
                    }
                )) { account in
                    HStack {
                        Image(systemName: icon(for: account))
                        VStack(alignment: .leading) {
                            Text(account.displayName)
                            Text(kindLabel(account))
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                        if account.id == main.account.state.selectedAccountId {
                            Text(L10n.Account.selected)
                                .font(.caption)
                                .foregroundStyle(palette.accent)
                        }
                    }
                    .tag(Optional(account.id))
                    .contextMenu {
                        Button(L10n.Common.delete, role: .destructive) {
                            Task { await main.account.delete(account) }
                        }
                    }
                }

                HStack {
                    TextField("Player", text: $main.account.newOfflineName)
                    Button(L10n.Account.addOffline) {
                        Task {
                            await main.account.addOffline()
                            main.accountState = main.account.state
                        }
                    }
                }

                Button {
                    Task {
                        await main.account.signInMicrosoft()
                        main.accountState = main.account.state
                    }
                } label: {
                    Label(L10n.Account.addMicrosoft, systemImage: "person.badge.key")
                }

                if let error = main.account.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .padding(20)
            .frame(minWidth: 320)

            VStack(alignment: .leading, spacing: 12) {
                if let selected = main.account.state.selectedAccount {
                    Text(selected.displayName)
                        .font(.largeTitle.weight(.bold))
                    LabeledContent("UUID", value: selected.uuid ?? "—")
                    LabeledContent("Type", value: kindLabel(selected))
                    // 2D skin placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(palette.card)
                        .frame(width: 160, height: 220)
                        .overlay {
                            Image(systemName: "person.crop.square")
                                .font(.system(size: 64))
                                .foregroundStyle(palette.secondaryText)
                        }
                } else {
                    EmptyStateView(title: L10n.Account.empty, systemImage: "person.crop.circle.badge.questionmark")
                }
                Spacer()
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .task {
            await main.account.reload()
            main.accountState = main.account.state
        }
    }

    private func icon(for account: LauncherAccountRecord) -> String {
        switch account.kind {
        case .microsoft: return "person.badge.key.fill"
        case .thirdParty: return "globe"
        default: return "person.fill"
        }
    }

    private func kindLabel(_ account: LauncherAccountRecord) -> String {
        switch account.kind {
        case .microsoft: return "Microsoft"
        case .thirdParty: return "Third-party"
        default: return "Offline"
        }
    }
}
