/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmDomain

@MainActor
public final class InstallViewModel: ObservableObject {
    @Published public var tasks: [InstallTask] = []
    private let container: AppContainer

    public init(container: AppContainer) {
        self.container = container
    }

    public func reload() async {
        tasks = container.installTasks.tasks
    }
}
