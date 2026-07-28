/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import AppKit
import BlockHelmDomain

@MainActor
public final class MultiplayerViewModel: ObservableObject {
    @Published public var worlds: [LanWorldAdvertisement] = []
    @Published public var isScanning = false
    @Published public var status: String = ""
    @Published public var errorMessage: String?

    private let container: AppContainer
    private var pollTask: Task<Void, Never>?

    public init(container: AppContainer) {
        self.container = container
    }

    public func start() async {
        isScanning = true
        errorMessage = nil
        status = L10n.Multiplayer.scanning
        await container.lanDiscovery.start()
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    public func stop() async {
        pollTask?.cancel()
        pollTask = nil
        await container.lanDiscovery.stop()
        isScanning = false
        status = ""
    }

    public func refresh() async {
        worlds = await container.lanDiscovery.snapshot()
        status = worlds.isEmpty
            ? L10n.Multiplayer.empty
            : L10n.Multiplayer.found(worlds.count)
    }

    public func copyAddress(_ world: LanWorldAdvertisement) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(world.joinAddress, forType: .string)
        status = L10n.Multiplayer.copied(world.joinAddress)
    }
}
