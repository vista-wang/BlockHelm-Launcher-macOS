/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmDomain

@MainActor
public final class AccountViewModel: ObservableObject {
    @Published public var state = LauncherAccountState()
    @Published public var newOfflineName = ""
    @Published public var errorMessage: String?
    @Published public var statusMessage: String?

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public func reload() async {
        do {
            state = try await container.accountStore.load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func addOffline() async {
        let account = container.offlineAccounts.createOfflineAccount(
            displayName: newOfflineName,
            mode: .standard,
            manualUuid: nil
        )
        state.accounts.append(account)
        state.selectedAccountId = account.id
        state.accountsInitialized = true
        newOfflineName = ""
        await persist()
    }

    public func select(_ account: LauncherAccountRecord) async {
        state.selectedAccountId = account.id
        await persist()
    }

    public func delete(_ account: LauncherAccountRecord) async {
        state.accounts.removeAll { $0.id == account.id }
        if state.selectedAccountId == account.id {
            state.selectedAccountId = state.accounts.first?.id
        }
        await persist()
    }

    public func signInMicrosoft() async {
        do {
            let account = try await container.microsoftAccounts.signIn()
            state.accounts.append(account)
            state.selectedAccountId = account.id
            await persist()
            statusMessage = account.displayName
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persist() async {
        do {
            try await container.accountStore.save(state)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
