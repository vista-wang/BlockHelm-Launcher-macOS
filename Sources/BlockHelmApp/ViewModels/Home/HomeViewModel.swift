/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmDomain

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public var instances: [GameInstance] = []
    @Published public var selectedInstanceId: String?
    @Published public var status: String = ""
    @Published public var progress: Double?
    @Published public var isLaunching = false
    @Published public var errorMessage: String?

    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public func reload(settings: LauncherSettings, accountState: LauncherAccountState) async {
        do {
            instances = try await container.instanceService.listInstances()
            if let defaultId = settings.defaultInstanceId,
               instances.contains(where: { $0.id == defaultId }) {
                selectedInstanceId = defaultId
            } else {
                selectedInstanceId = instances.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public var selectedInstance: GameInstance? {
        instances.first { $0.id == selectedInstanceId }
    }

    public func launch(accountState: LauncherAccountState, settings: LauncherSettings) async {
        guard let instance = selectedInstance else {
            errorMessage = L10n.Home.noInstance
            return
        }
        guard let accountRecord = accountState.selectedAccount else {
            errorMessage = L10n.Account.empty
            return
        }
        isLaunching = true
        errorMessage = nil
        defer { isLaunching = false }

        do {
            try await container.launchIntegrity.validate(instance: instance, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let launchAccount: LaunchAccount
        do {
            if accountRecord.kind == .microsoft, accountRecord.isOffline == false {
                launchAccount = try await container.microsoftAccounts.launchAccount(for: accountRecord)
            } else {
                launchAccount = LaunchAccount.offline(from: accountRecord)
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        do {
            _ = try await container.launchService.launch(
                instance: instance,
                account: launchAccount,
                settings: settings
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.status = progress.message
                    self?.progress = progress.percent
                }
            }
            status = "OK"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
