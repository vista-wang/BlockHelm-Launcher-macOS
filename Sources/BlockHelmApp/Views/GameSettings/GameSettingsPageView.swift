/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI
import BlockHelmDomain
import UniformTypeIdentifiers

struct GameSettingsPageView: View {
    @EnvironmentObject private var main: MainViewModel
    @Environment(\.themePalette) private var palette
    @State private var isImportingSave = false

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
                    Section {
                        Picker(L10n.Resources.kind, selection: $main.gameSettings.contentKind) {
                            Text(L10n.Resources.mods).tag(ModrinthProjectKind.mod)
                            Text(L10n.Resources.resourcePacks).tag(ModrinthProjectKind.resourcepack)
                            Text(L10n.Resources.shaders).tag(ModrinthProjectKind.shader)
                            Text(L10n.Resources.worlds).tag(ModrinthProjectKind.world)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: main.gameSettings.contentKind) { _ in
                            Task { await main.gameSettings.reloadContent() }
                        }
                    }
                    if main.gameSettings.showingSaves {
                        Section(L10n.Saves.title) {
                            Button(L10n.Saves.importZip) { isImportingSave = true }
                            if main.gameSettings.saves.isEmpty {
                                Text(L10n.Saves.empty)
                                    .foregroundStyle(palette.secondaryText)
                            } else {
                                ForEach(main.gameSettings.saves) { save in
                                    HStack {
                                        Text(save.name)
                                        Spacer()
                                        Button(L10n.Common.delete, role: .destructive) {
                                            Task { await main.gameSettings.deleteSave(save) }
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                    } else {
                        Section(contentSectionTitle) {
                            if main.gameSettings.contentItems.isEmpty {
                                Text(L10n.Resources.noContent)
                                    .foregroundStyle(palette.secondaryText)
                            } else {
                                ForEach(main.gameSettings.contentItems) { item in
                                    HStack {
                                        Toggle(item.displayName, isOn: Binding(
                                            get: { item.isEnabled },
                                            set: { _ in
                                                Task { await main.gameSettings.toggleContent(item) }
                                            }
                                        ))
                                        Spacer()
                                        Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                                            .font(.caption)
                                            .foregroundStyle(palette.secondaryText)
                                        Button(L10n.Common.delete, role: .destructive) {
                                            Task { await main.gameSettings.deleteContent(item) }
                                        }
                                        .buttonStyle(.borderless)
                                    }
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
                    if let status = main.gameSettings.statusMessage {
                        Text(status).foregroundStyle(palette.secondaryText)
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
        .fileImporter(
            isPresented: $isImportingSave,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                Task {
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    await main.gameSettings.importSave(from: url)
                }
            case .failure(let error):
                main.gameSettings.errorMessage = error.localizedDescription
            }
        }
    }

    private var contentSectionTitle: String {
        switch main.gameSettings.contentKind {
        case .mod: return L10n.Resources.mods
        case .resourcepack: return L10n.Resources.resourcePacks
        case .shader: return L10n.Resources.shaders
        case .world: return L10n.Saves.title
        }
    }

    private var selectedBinding: Binding<GameInstance>? {
        guard main.gameSettings.selected != nil else { return nil }
        return Binding(
            get: { main.gameSettings.selected! },
            set: { main.gameSettings.selected = $0 }
        )
    }
}
