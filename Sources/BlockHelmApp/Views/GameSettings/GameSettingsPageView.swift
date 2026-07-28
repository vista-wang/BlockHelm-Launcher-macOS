/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI
import BlockHelmDomain

struct GameSettingsPageView: View {
    @EnvironmentObject private var main: MainViewModel
    @Environment(\.themePalette) private var palette

    var body: some View {
        HSplitView {
            List(main.gameSettings.instances, selection: Binding(
                get: { main.gameSettings.selected?.id },
                set: { id in
                    if let instance = main.gameSettings.instances.first(where: { $0.id == id }) {
                        Task { await main.gameSettings.select(instance) }
                    }
                }
            )) { instance in
                VStack(alignment: .leading) {
                    Text(instance.name).font(.headline)
                    Text("\(instance.loader.displayName) · \(instance.minecraftVersion)")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
                .tag(Optional(instance.id))
            }
            .frame(minWidth: 260)

            if let binding = selectedBinding {
                Form {
                    Section(L10n.Settings.general) {
                        TextField("Name", text: binding.name)
                        LabeledContent("Version", value: binding.wrappedValue.versionName)
                        LabeledContent("Loader", value: binding.wrappedValue.loader.displayName)
                    }
                    Section(L10n.Settings.memory) {
                        Picker("Mode", selection: binding.memorySettingsMode) {
                            Text("Auto").tag(MemorySettingsMode.auto)
                            Text("Manual").tag(MemorySettingsMode.manual)
                        }
                        Stepper(value: binding.memoryMb, in: 1024...32768, step: 512) {
                            Text("\(binding.wrappedValue.memoryMb) MB")
                        }
                    }
                    Section("Window") {
                        Stepper(value: binding.windowWidth, in: 800...7680, step: 10) {
                            Text("Width \(binding.wrappedValue.windowWidth)")
                        }
                        Stepper(value: binding.windowHeight, in: 600...4320, step: 10) {
                            Text("Height \(binding.wrappedValue.windowHeight)")
                        }
                        Toggle("Fullscreen", isOn: binding.launchFullScreen)
                    }
                    Section(L10n.Resources.mods) {
                        if main.gameSettings.mods.isEmpty {
                            Text(L10n.Resources.noMods)
                                .foregroundStyle(palette.secondaryText)
                        } else {
                            ForEach(main.gameSettings.mods) { mod in
                                HStack {
                                    Toggle(mod.displayName, isOn: Binding(
                                        get: { mod.isEnabled },
                                        set: { _ in
                                            Task { await main.gameSettings.toggleMod(mod) }
                                        }
                                    ))
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: mod.fileSize, countStyle: .file))
                                        .font(.caption)
                                        .foregroundStyle(palette.secondaryText)
                                    Button(L10n.Common.delete, role: .destructive) {
                                        Task { await main.gameSettings.deleteMod(mod) }
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                    Section {
                        Button(L10n.Settings.save) {
                            Task { await main.gameSettings.saveSelected() }
                        }
                        .buttonStyle(.borderedProminent)
                        Button(L10n.Common.delete, role: .destructive) {
                            Task {
                                await main.gameSettings.deleteSelected()
                                await main.home.reload(settings: main.settings, accountState: main.accountState)
                            }
                        }
                    }
                    if let error = main.gameSettings.errorMessage {
                        Text(error).foregroundStyle(.red)
                    }
                }
                .formStyle(.grouped)
                .padding()
            } else {
                EmptyStateView(title: L10n.Page.gameSettings, systemImage: "shippingbox")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await main.gameSettings.reload() }
    }

    private var selectedBinding: Binding<GameInstance>? {
        guard main.gameSettings.selected != nil else { return nil }
        return Binding(
            get: { main.gameSettings.selected! },
            set: { main.gameSettings.selected = $0 }
        )
    }
}
