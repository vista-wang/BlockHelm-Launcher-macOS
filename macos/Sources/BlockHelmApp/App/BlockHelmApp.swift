/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI

@main
struct BlockHelmApp: App {
    @StateObject private var mainViewModel: MainViewModel

    init() {
        let container = AppContainer()
        _mainViewModel = StateObject(wrappedValue: MainViewModel(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootShellView()
                .environmentObject(mainViewModel)
                .environmentObject(mainViewModel.container)
                .frame(minWidth: 960, minHeight: 640)
                .task {
                    await mainViewModel.bootstrap()
                }
        }
        .windowStyle(.automatic)
    }
}
