/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI
import BlockHelmDomain

struct SettingsPageView: View {
    @EnvironmentObject private var main: MainViewModel
    @Environment(\.themePalette) private var palette

    var body: some View {
        Form {
            Section(L10n.Settings.general) {
                TextField("Data directory", text: $main.settingsPage.draft.dataDirectory)
                TextField("Minecraft directory", text: $main.settingsPage.draft.minecraftDirectory)
            }

            Section(L10n.Settings.language) {
                Picker(L10n.Settings.language, selection: $main.settingsPage.draft.launcherLanguage) {
                    Text("简体中文").tag("zh-Hans")
                    Text("繁體中文").tag("zh-Hant")
                    Text("English").tag("en")
                    Text("日本語").tag("ja-JP")
                }
            }

            Section(L10n.Settings.download) {
                Picker("Source", selection: $main.settingsPage.draft.downloadSourcePreference) {
                    Text("Official").tag(DownloadSourcePreference.official)
                    Text("BMCLAPI").tag(DownloadSourcePreference.bmclApi)
                }
                Stepper(value: $main.settingsPage.draft.maximumDownloadConcurrency, in: 1...128) {
                    Text("Concurrency \(main.settingsPage.draft.maximumDownloadConcurrency)")
                }
            }

            Section(L10n.Settings.memory) {
                Picker("Mode", selection: $main.settingsPage.draft.defaultMemorySettingsMode) {
                    Text("Auto").tag(MemorySettingsMode.auto)
                    Text("Manual").tag(MemorySettingsMode.manual)
                }
                Stepper(value: $main.settingsPage.draft.defaultMemoryMb, in: 1024...32768, step: 512) {
                    Text("\(main.settingsPage.draft.defaultMemoryMb) MB")
                }
            }

            Section(L10n.Settings.java) {
                Picker("Selection", selection: $main.settingsPage.draft.javaSelectionMode) {
                    Text("Auto").tag(JavaSelectionMode.auto)
                    Text("Manual").tag(JavaSelectionMode.manual)
                }
                if main.settingsPage.javaRuntimes.isEmpty {
                    Text("No Java found").foregroundStyle(palette.secondaryText)
                } else {
                    Picker("Runtime", selection: Binding(
                        get: { main.settingsPage.draft.selectedJavaExecutablePath ?? main.settingsPage.javaRuntimes.first?.executablePath },
                        set: { main.settingsPage.draft.selectedJavaExecutablePath = $0 }
                    )) {
                        ForEach(main.settingsPage.javaRuntimes) { runtime in
                            Text("\(runtime.displayName) · \(runtime.source)")
                                .tag(Optional(runtime.executablePath))
                        }
                    }
                }
            }

            Section(L10n.Settings.theme) {
                Toggle(L10n.Settings.followSystem, isOn: $main.settingsPage.draft.themeFollowSystem)
                Picker("Theme", selection: $main.settingsPage.draft.theme) {
                    Text("Dark").tag("Dark")
                    Text("Light").tag("Light")
                }
                .disabled(main.settingsPage.draft.themeFollowSystem)
                Picker("Accent", selection: $main.settingsPage.draft.accentColor) {
                    ForEach(AppAccent.allCases) { accent in
                        Text(accent.rawValue).tag(accent.rawValue)
                    }
                }
            }

            Section(L10n.Settings.info) {
                LabeledContent("Version", value: "0.9.11-macos")
                LabeledContent("Platform", value: "macOS / SwiftUI")
                Link("GitHub", destination: URL(string: "https://github.com/vista-wang/BlockHelm-Launcher-macOS")!)
            }

            Section {
                Button(L10n.Settings.save) {
                    Task {
                        if let saved = await main.settingsPage.save() {
                            main.settings = saved
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                if let message = main.settingsPage.savedMessage {
                    Text(message).foregroundStyle(palette.accent)
                }
                if let error = main.settingsPage.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { await main.settingsPage.reload() }
    }
}
