/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import CryptoKit
import BlockHelmApplication
import BlockHelmDomain

public final class LocalSaveServiceImpl: LocalSaveService, @unchecked Sendable {
    public init() {}

    public func listSaves(instance: GameInstance) async throws -> [LocalSave] {
        let saves = URL(fileURLWithPath: instance.instanceDirectory)
            .appendingPathComponent("saves", isDirectory: true)
        try FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)
        let children = try FileManager.default.contentsOfDirectory(
            at: saves,
            includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return children.compactMap { url -> LocalSave? in
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                return nil
            }
            guard FileManager.default.fileExists(atPath: url.appendingPathComponent("level.dat").path) else {
                return nil
            }
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            return LocalSave(
                name: url.lastPathComponent,
                directoryName: url.lastPathComponent,
                fullPath: url.path,
                createdAt: created
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func importFromZip(instance: GameInstance, archiveURL: URL) async throws -> LocalSave {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("bhl-save-import-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try ZipExtractor.extractAll(archive: archiveURL, to: staging)

        let root = try WorldInstallHelper.resolveWorldRoot(in: staging)
        let preferred = WorldInstallHelper.sanitize(
            root == staging ? archiveURL.deletingPathExtension().lastPathComponent : root.lastPathComponent
        )
        let saves = URL(fileURLWithPath: instance.instanceDirectory)
            .appendingPathComponent("saves", isDirectory: true)
        try FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)

        var destination = saves.appendingPathComponent(preferred, isDirectory: true)
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = saves.appendingPathComponent("\(preferred)-\(suffix)", isDirectory: true)
            suffix += 1
        }

        if root == staging {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            for child in try FileManager.default.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil) {
                try FileManager.default.moveItem(
                    at: child,
                    to: destination.appendingPathComponent(child.lastPathComponent)
                )
            }
        } else {
            try FileManager.default.moveItem(at: root, to: destination)
        }

        return LocalSave(
            name: destination.lastPathComponent,
            directoryName: destination.lastPathComponent,
            fullPath: destination.path
        )
    }

    public func delete(_ save: LocalSave) async throws {
        try FileManager.default.removeItem(at: URL(fileURLWithPath: save.fullPath))
    }
}

public final class ModpackImportServiceImpl: ModpackImportService, @unchecked Sendable {
    private let client: HTTPClient
    private let installService: GameInstallService
    private let versionService: GameVersionService

    public init(
        client: HTTPClient,
        installService: GameInstallService,
        versionService: GameVersionService
    ) {
        self.client = client
        self.installService = installService
        self.versionService = versionService
    }

    public func importMrpack(
        archiveURL: URL,
        instanceName: String?,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance {
        progress(LauncherProgress(stage: InstallProgressStages.preparing, message: "Reading modpack…", percent: 0.05))
        guard let indexData = try ZipExtractor.readFile(named: "modrinth.index.json", from: archiveURL) else {
            throw ModpackImportError.missingIndex
        }
        let index = try JSONDecoder().decode(MrpackIndex.self, from: indexData)
        guard let minecraft = index.dependencies.minecraft, !minecraft.isEmpty else {
            throw ModpackImportError.missingMinecraft
        }

        let loaderInfo = try index.dependencies.resolveLoader()
        let name = (instanceName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? index.name
            ?? archiveURL.deletingPathExtension().lastPathComponent

        progress(LauncherProgress(stage: InstallProgressStages.preparing, message: "Installing \(loaderInfo.loader.displayName)…", percent: 0.15))
        let instance = try await installLoader(
            minecraftVersion: minecraft,
            loader: loaderInfo.loader,
            loaderVersion: loaderInfo.version,
            instanceName: name,
            settings: settings,
            progress: progress
        )

        let root = URL(fileURLWithPath: instance.instanceDirectory)
        let files = index.files.filter { !$0.isClientUnsupported }
        for (offset, file) in files.enumerated() {
            let fraction = 0.25 + 0.55 * Double(offset) / Double(max(files.count, 1))
            progress(LauncherProgress(
                stage: InstallProgressStages.completingFiles,
                message: "Downloading \(file.path)",
                percent: fraction
            ))
            guard let urlString = file.downloads.first(where: { URL(string: $0) != nil }),
                  let url = URL(string: urlString)
            else {
                throw ModpackImportError.missingDownloadURL(file.path)
            }
            let destination = root.appendingPathComponent(file.path)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destination.path) { continue }
            try await client.download(from: url, to: destination)
            try verifyHashes(file: file, at: destination)
        }

        progress(LauncherProgress(stage: InstallProgressStages.finalizingVersion, message: "Applying overrides…", percent: 0.9))
        try applyOverrides(from: archiveURL, to: root, prefix: "overrides/")
        try applyOverrides(from: archiveURL, to: root, prefix: "client-overrides/")

        progress(LauncherProgress(stage: InstallProgressStages.finalizingVersion, message: "Modpack ready", percent: 1))
        return instance
    }

    private func installLoader(
        minecraftVersion: String,
        loader: LoaderKind,
        loaderVersion: String?,
        instanceName: String,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance {
        switch loader {
        case .vanilla:
            let versions = try await versionService.listVersions(
                source: settings.downloadSourcePreference,
                includeSnapshots: true
            )
            guard let version = versions.first(where: { $0.name == minecraftVersion }) else {
                throw ModpackImportError.unknownMinecraftVersion(minecraftVersion)
            }
            return try await installService.installVanilla(
                version: version,
                instanceName: instanceName,
                settings: settings,
                progress: progress
            )
        case .fabric:
            return try await installService.installFabric(
                minecraftVersion: minecraftVersion,
                loaderVersion: loaderVersion,
                instanceName: instanceName,
                settings: settings,
                progress: progress
            )
        case .quilt:
            return try await installService.installQuilt(
                minecraftVersion: minecraftVersion,
                loaderVersion: loaderVersion,
                instanceName: instanceName,
                settings: settings,
                progress: progress
            )
        case .forge:
            return try await installService.installForge(
                minecraftVersion: minecraftVersion,
                loaderVersion: loaderVersion,
                instanceName: instanceName,
                settings: settings,
                progress: progress
            )
        case .neoForge:
            return try await installService.installNeoForge(
                minecraftVersion: minecraftVersion,
                loaderVersion: loaderVersion,
                instanceName: instanceName,
                settings: settings,
                progress: progress
            )
        }
    }

    private func applyOverrides(from archive: URL, to root: URL, prefix: String) throws {
        let entries = try ZipExtractor.readEntries(from: archive)
        for entry in entries {
            let name = entry.name.replacingOccurrences(of: "\\", with: "/")
            guard name.hasPrefix(prefix), !name.hasSuffix("/") else { continue }
            let relative = String(name.dropFirst(prefix.count))
            guard !relative.isEmpty else { continue }
            let destination = root.appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try entry.data.write(to: destination, options: .atomic)
        }
    }

    private func verifyHashes(file: MrpackFile, at url: URL) throws {
        let data = try Data(contentsOf: url)
        if let sha512 = file.hashes.sha512, !sha512.isEmpty {
            let digest = SHA512.hash(data: data)
            let actual = digest.map { String(format: "%02x", $0) }.joined()
            if actual != sha512.lowercased() {
                try? FileManager.default.removeItem(at: url)
                throw ModpackImportError.checksumMismatch(file.path)
            }
        } else if let sha1 = file.hashes.sha1, !sha1.isEmpty {
            let digest = Insecure.SHA1.hash(data: data)
            let actual = digest.map { String(format: "%02x", $0) }.joined()
            if actual != sha1.lowercased() {
                try? FileManager.default.removeItem(at: url)
                throw ModpackImportError.checksumMismatch(file.path)
            }
        }
    }

    private struct MrpackIndex: Decodable {
        let name: String?
        let dependencies: Dependencies
        let files: [MrpackFile]

        struct Dependencies: Decodable {
            let minecraft: String?
            let fabricLoader: String?
            let quiltLoader: String?
            let forge: String?
            let neoforge: String?

            enum CodingKeys: String, CodingKey {
                case minecraft
                case fabricLoader = "fabric-loader"
                case quiltLoader = "quilt-loader"
                case forge
                case neoforge
            }

            func resolveLoader() throws -> (loader: LoaderKind, version: String?) {
                var found: [(LoaderKind, String?)] = []
                if let fabricLoader { found.append((.fabric, fabricLoader)) }
                if let quiltLoader { found.append((.quilt, quiltLoader)) }
                if let forge { found.append((.forge, forge)) }
                if let neoforge { found.append((.neoForge, neoforge)) }
                switch found.count {
                case 0: return (.vanilla, nil)
                case 1: return found[0]
                default: throw ModpackImportError.multipleLoaders
                }
            }
        }
    }

    private struct MrpackFile: Decodable {
        let path: String
        let hashes: Hashes
        let downloads: [String]
        let env: Env?

        struct Hashes: Decodable {
            let sha1: String?
            let sha512: String?
        }

        struct Env: Decodable {
            let client: String?
            let server: String?
        }

        var isClientUnsupported: Bool {
            env?.client?.lowercased() == "unsupported"
        }
    }
}

public enum ModpackImportError: LocalizedError {
    case missingIndex
    case missingMinecraft
    case multipleLoaders
    case missingDownloadURL(String)
    case checksumMismatch(String)
    case unknownMinecraftVersion(String)

    public var errorDescription: String? {
        switch self {
        case .missingIndex:
            return "modrinth.index.json was not found in the archive."
        case .missingMinecraft:
            return "Modpack is missing a Minecraft version dependency."
        case .multipleLoaders:
            return "Modpack declares multiple loaders."
        case .missingDownloadURL(let path):
            return "Missing download URL for \(path)."
        case .checksumMismatch(let path):
            return "Checksum mismatch for \(path)."
        case .unknownMinecraftVersion(let version):
            return "Unknown Minecraft version \(version)."
        }
    }
}
