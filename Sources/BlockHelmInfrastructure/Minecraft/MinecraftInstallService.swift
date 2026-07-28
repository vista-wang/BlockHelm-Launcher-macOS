/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmApplication
import BlockHelmDomain

public final class MinecraftInstallService: GameInstallService, @unchecked Sendable {
    private let client: HTTPClient
    private let pathProvider: LauncherPathProviding
    private let instanceService: GameInstanceService
    private let javaDiscovery: JavaRuntimeDiscoveryService
    private let loaderCatalog: LoaderCatalogService

    public init(
        client: HTTPClient = HTTPClient(),
        pathProvider: LauncherPathProviding,
        instanceService: GameInstanceService,
        javaDiscovery: JavaRuntimeDiscoveryService,
        loaderCatalog: LoaderCatalogService? = nil
    ) {
        self.client = client
        self.pathProvider = pathProvider
        self.instanceService = instanceService
        self.javaDiscovery = javaDiscovery
        self.loaderCatalog = loaderCatalog ?? LoaderCatalogServiceImpl(client: client)
    }

    public func installVanilla(
        version: MinecraftVersionInfo,
        instanceName: String,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance {
        progress(LauncherProgress(stage: InstallProgressStages.preparing, message: "Preparing \(version.name)", percent: 0))
        try await ensureVersionFiles(
            versionName: version.name,
            versionURLString: version.url,
            source: settings.downloadSourcePreference,
            progress: progress
        )
        progress(LauncherProgress(stage: InstallProgressStages.finalizingVersion, message: "Creating instance", percent: 0.95))
        return try await instanceService.createInstance(
            name: instanceName.isEmpty ? version.name : instanceName,
            minecraftVersion: version.name,
            versionType: version.type,
            loader: .vanilla,
            loaderVersion: nil,
            settings: settings
        )
    }

    public func installFabric(
        minecraftVersion: String,
        loaderVersion: String?,
        instanceName: String,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance {
        progress(LauncherProgress(stage: InstallProgressStages.preparing, message: "Resolving Fabric", percent: 0))

        let versions = try await MojangGameVersionService(client: client, pathProvider: pathProvider)
            .listVersions(source: settings.downloadSourcePreference, includeSnapshots: true)
        guard let vanilla = versions.first(where: { $0.name == minecraftVersion }) else {
            throw InstallError.versionNotFound(minecraftVersion)
        }

        try await ensureVersionFiles(
            versionName: vanilla.name,
            versionURLString: vanilla.url,
            source: settings.downloadSourcePreference,
            progress: progress
        )

        let loader = try await resolveFabricLoaderVersion(minecraftVersion: minecraftVersion, preferred: loaderVersion)
        let profileURL = URL(string: "\(DownloadSourceURLs.fabricMeta)/versions/loader/\(minecraftVersion)/\(loader)/profile/json")!
        let profileData = try await client.data(from: profileURL)
        let fabricProfile = try JSONDecoder.minecraft.decode(VersionJSON.self, from: profileData)

        let versionName = "fabric-loader-\(loader)-\(minecraftVersion)"
        let versionDir = pathProvider.versionDirectory(versionName: versionName)
        try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true)
        try profileData.write(to: versionDir.appendingPathComponent("\(versionName).json"), options: .atomic)

        try await downloadLibraries(fabricProfile, source: settings.downloadSourcePreference)
        try await extractNatives(fabricProfile, versionName: versionName)

        progress(LauncherProgress(stage: InstallProgressStages.finalizingVersion, message: "Creating Fabric instance", percent: 0.95))
        return try await instanceService.createInstance(
            name: instanceName.isEmpty ? versionName : instanceName,
            minecraftVersion: minecraftVersion,
            versionType: "release",
            loader: .fabric,
            loaderVersion: loader,
            settings: settings
        )
    }

    public func installQuilt(
        minecraftVersion: String,
        loaderVersion: String?,
        instanceName: String,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance {
        progress(LauncherProgress(stage: InstallProgressStages.preparing, message: "Resolving Quilt", percent: 0))

        let versions = try await MojangGameVersionService(client: client, pathProvider: pathProvider)
            .listVersions(source: settings.downloadSourcePreference, includeSnapshots: true)
        guard let vanilla = versions.first(where: { $0.name == minecraftVersion }) else {
            throw InstallError.versionNotFound(minecraftVersion)
        }

        try await ensureVersionFiles(
            versionName: vanilla.name,
            versionURLString: vanilla.url,
            source: settings.downloadSourcePreference,
            progress: progress
        )

        let loader = try await resolveQuiltLoaderVersion(minecraftVersion: minecraftVersion, preferred: loaderVersion)
        let profileURL = URL(string: "\(DownloadSourceURLs.quiltMeta)/versions/loader/\(minecraftVersion)/\(loader)/profile/json")!
        let profileData = try await client.data(from: profileURL)
        let quiltProfile = try JSONDecoder.minecraft.decode(VersionJSON.self, from: profileData)

        let versionName = "quilt-loader-\(loader)-\(minecraftVersion)"
        let versionDir = pathProvider.versionDirectory(versionName: versionName)
        try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true)
        try profileData.write(to: versionDir.appendingPathComponent("\(versionName).json"), options: .atomic)

        try await downloadLibraries(quiltProfile, source: settings.downloadSourcePreference)
        try await extractNatives(quiltProfile, versionName: versionName)

        progress(LauncherProgress(stage: InstallProgressStages.finalizingVersion, message: "Creating Quilt instance", percent: 0.95))
        return try await instanceService.createInstance(
            name: instanceName.isEmpty ? versionName : instanceName,
            minecraftVersion: minecraftVersion,
            versionType: "release",
            loader: .quilt,
            loaderVersion: loader,
            settings: settings
        )
    }

    public func installForge(
        minecraftVersion: String,
        loaderVersion: String?,
        instanceName: String,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance {
        try await installViaJavaInstaller(
            kind: .forge,
            minecraftVersion: minecraftVersion,
            loaderVersion: loaderVersion,
            instanceName: instanceName,
            settings: settings,
            progress: progress
        )
    }

    public func installNeoForge(
        minecraftVersion: String,
        loaderVersion: String?,
        instanceName: String,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance {
        try await installViaJavaInstaller(
            kind: .neoForge,
            minecraftVersion: minecraftVersion,
            loaderVersion: loaderVersion,
            instanceName: instanceName,
            settings: settings,
            progress: progress
        )
    }

    private func installViaJavaInstaller(
        kind: LoaderKind,
        minecraftVersion: String,
        loaderVersion: String?,
        instanceName: String,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> GameInstance {
        progress(LauncherProgress(stage: InstallProgressStages.preparing, message: "Resolving \(kind.displayName)", percent: 0))

        let versions = try await MojangGameVersionService(client: client, pathProvider: pathProvider)
            .listVersions(source: settings.downloadSourcePreference, includeSnapshots: true)
        guard let vanilla = versions.first(where: { $0.name == minecraftVersion }) else {
            throw InstallError.versionNotFound(minecraftVersion)
        }

        try await ensureVersionFiles(
            versionName: vanilla.name,
            versionURLString: vanilla.url,
            source: settings.downloadSourcePreference,
            progress: progress
        )

        let catalog: [LoaderVersionInfo]
        switch kind {
        case .forge:
            catalog = try await loaderCatalog.listForgeVersions(
                minecraftVersion: minecraftVersion,
                source: settings.downloadSourcePreference
            )
        case .neoForge:
            catalog = try await loaderCatalog.listNeoForgeVersions(
                minecraftVersion: minecraftVersion,
                source: settings.downloadSourcePreference
            )
        default:
            throw InstallError.loaderNotFound
        }

        let selected: LoaderVersionInfo
        if let preferred = loaderVersion, !preferred.isEmpty,
           let match = catalog.first(where: { $0.version == preferred }) {
            selected = match
        } else if let first = catalog.first {
            selected = first
        } else {
            throw InstallError.loaderNotFound
        }

        guard let installerURLString = selected.installerURL,
              let installerURL = URL(string: installerURLString)
        else { throw InstallError.loaderNotFound }

        progress(LauncherProgress(stage: InstallProgressStages.checkingJava, message: "Resolving Java", percent: 0.2))
        guard let java = await javaDiscovery.resolveExecutable(settings: settings, instance: nil) else {
            throw InstallError.javaNotFound
        }

        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("blockhelm-\(kind.catalogSlug)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        let installerJar = workDir.appendingPathComponent("installer.jar")
        progress(LauncherProgress(
            stage: InstallProgressStages.downloadingLoaderInstaller,
            message: "Downloading \(kind.displayName) installer",
            percent: 0.3
        ))
        try await client.download(from: installerURL, to: installerJar)

        let versionsRoot = pathProvider.minecraftDirectory.appendingPathComponent("versions", isDirectory: true)
        let before = Set((try? FileManager.default.contentsOfDirectory(atPath: versionsRoot.path)) ?? [])

        progress(LauncherProgress(
            stage: InstallProgressStages.runningLoaderInstaller,
            message: "Running \(kind.displayName) installer",
            percent: 0.5
        ))
        try await ForgeInstallerRunner.run(
            javaPath: java.executablePath,
            installerJar: installerJar,
            minecraftDirectory: pathProvider.minecraftDirectory
        )

        let after = Set((try? FileManager.default.contentsOfDirectory(atPath: versionsRoot.path)) ?? [])
        let created = after.subtracting(before)
        let outputName = try resolveInstallerOutputVersionName(
            kind: kind,
            minecraftVersion: minecraftVersion,
            loaderVersion: selected.version,
            created: created
        )

        let versionDir = pathProvider.versionDirectory(versionName: outputName)
        let jsonURL = versionDir.appendingPathComponent("\(outputName).json")
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw InstallError.installerOutputMissing
        }

        let raw = try Data(contentsOf: jsonURL)
        let versionJSON = try JSONDecoder.minecraft.decode(VersionJSON.self, from: raw)
        progress(LauncherProgress(stage: InstallProgressStages.completingFiles, message: "Downloading libraries", percent: 0.75))
        try await downloadLibraries(versionJSON, source: settings.downloadSourcePreference)
        try await extractNatives(versionJSON, versionName: outputName)

        let finalName: String
        switch kind {
        case .forge:
            finalName = "\(minecraftVersion)-forge-\(selected.version)"
        case .neoForge:
            finalName = "neoforge-\(selected.version)"
        default:
            finalName = outputName
        }

        if finalName != outputName {
            try renameVersionDirectory(from: outputName, to: finalName)
        }

        progress(LauncherProgress(stage: InstallProgressStages.finalizingVersion, message: "Creating instance", percent: 0.95))
        return try await instanceService.createInstance(
            name: instanceName.isEmpty ? finalName : instanceName,
            minecraftVersion: minecraftVersion,
            versionType: "release",
            loader: kind,
            loaderVersion: selected.version,
            settings: settings
        )
    }

    private func resolveInstallerOutputVersionName(
        kind: LoaderKind,
        minecraftVersion: String,
        loaderVersion: String,
        created: Set<String>
    ) throws -> String {
        let candidates = Array(created)
        if let exact = candidates.first(where: {
            $0.localizedCaseInsensitiveContains(loaderVersion)
                && $0.localizedCaseInsensitiveContains(kind == .neoForge ? "neoforge" : "forge")
        }) {
            return exact
        }
        if let any = candidates.first {
            return any
        }
        // Installer may overwrite existing version folder.
        let preferred: [String]
        switch kind {
        case .forge:
            preferred = [
                "\(minecraftVersion)-forge-\(loaderVersion)",
                "\(minecraftVersion)-forge\(loaderVersion)",
                "forge-\(minecraftVersion)-\(loaderVersion)"
            ]
        case .neoForge:
            preferred = [
                "neoforge-\(loaderVersion)",
                "\(minecraftVersion)-neoforge-\(loaderVersion)"
            ]
        default:
            preferred = []
        }
        for name in preferred {
            let json = pathProvider.versionDirectory(versionName: name)
                .appendingPathComponent("\(name).json")
            if FileManager.default.fileExists(atPath: json.path) {
                return name
            }
        }
        throw InstallError.installerOutputMissing
    }

    private func renameVersionDirectory(from oldName: String, to newName: String) throws {
        let fm = FileManager.default
        let oldDir = pathProvider.versionDirectory(versionName: oldName)
        let newDir = pathProvider.versionDirectory(versionName: newName)
        if fm.fileExists(atPath: newDir.path) {
            try fm.removeItem(at: newDir)
        }
        try fm.moveItem(at: oldDir, to: newDir)
        let oldJSON = newDir.appendingPathComponent("\(oldName).json")
        let newJSON = newDir.appendingPathComponent("\(newName).json")
        if fm.fileExists(atPath: oldJSON.path) {
            if var obj = try JSONSerialization.jsonObject(with: Data(contentsOf: oldJSON)) as? [String: Any] {
                obj["id"] = newName
                let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: newJSON, options: .atomic)
                try? fm.removeItem(at: oldJSON)
            } else {
                try fm.moveItem(at: oldJSON, to: newJSON)
            }
        }
        let oldJar = newDir.appendingPathComponent("\(oldName).jar")
        let newJar = newDir.appendingPathComponent("\(newName).jar")
        if fm.fileExists(atPath: oldJar.path), !fm.fileExists(atPath: newJar.path) {
            try fm.moveItem(at: oldJar, to: newJar)
        }
    }

    private func ensureVersionFiles(
        versionName: String,
        versionURLString: String?,
        source: DownloadSourcePreference,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws {
        guard let versionURLString,
              let versionURL = DownloadSourceURLs.rewrite(versionURLString, source: source)
        else {
            throw InstallError.missingVersionURL
        }

        let versionDir = pathProvider.versionDirectory(versionName: versionName)
        try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true)
        let jsonURL = versionDir.appendingPathComponent("\(versionName).json")
        let raw = try await client.data(from: versionURL)
        try raw.write(to: jsonURL, options: .atomic)
        let versionJSON = try JSONDecoder.minecraft.decode(VersionJSON.self, from: raw)

        progress(LauncherProgress(stage: InstallProgressStages.completingFiles, message: "Downloading client", percent: 0.1))
        try await downloadClientJar(versionJSON, versionName: versionName, source: source)

        progress(LauncherProgress(stage: InstallProgressStages.completingFiles, message: "Downloading libraries", percent: 0.3))
        try await downloadLibraries(versionJSON, source: source)

        if let assetIndex = versionJSON.assetIndex {
            progress(LauncherProgress(stage: InstallProgressStages.completingFiles, message: "Downloading assets", percent: 0.5))
            try await downloadAssets(assetIndex, source: source, progress: progress)
        }

        progress(LauncherProgress(stage: InstallProgressStages.completingFiles, message: "Extracting natives", percent: 0.9))
        try await extractNatives(versionJSON, versionName: versionName)
        progress(LauncherProgress(stage: InstallProgressStages.completingFiles, message: "Files ready", percent: 1))
    }

    private func resolveFabricLoaderVersion(minecraftVersion: String, preferred: String?) async throws -> String {
        if let preferred, !preferred.isEmpty { return preferred }
        struct LoaderEntry: Decodable {
            struct Loader: Decodable { let version: String; let stable: Bool? }
            let loader: Loader
        }
        let url = URL(string: "\(DownloadSourceURLs.fabricMeta)/versions/loader/\(minecraftVersion)")!
        let entries = try await client.json([LoaderEntry].self, from: url)
        if let stable = entries.first(where: { $0.loader.stable == true }) {
            return stable.loader.version
        }
        guard let first = entries.first else { throw InstallError.loaderNotFound }
        return first.loader.version
    }

    private func resolveQuiltLoaderVersion(minecraftVersion: String, preferred: String?) async throws -> String {
        if let preferred, !preferred.isEmpty { return preferred }
        struct LoaderEntry: Decodable {
            struct Loader: Decodable { let version: String; let stable: Bool? }
            let loader: Loader
        }
        let url = URL(string: "\(DownloadSourceURLs.quiltMeta)/versions/loader/\(minecraftVersion)")!
        let entries = try await client.json([LoaderEntry].self, from: url)
        if let stable = entries.first(where: { $0.loader.stable == true }) {
            return stable.loader.version
        }
        guard let first = entries.first else { throw InstallError.loaderNotFound }
        return first.loader.version
    }

    private func downloadClientJar(
        _ version: VersionJSON,
        versionName: String,
        source: DownloadSourcePreference
    ) async throws {
        guard let clientDownload = version.downloads?.client,
              let url = DownloadSourceURLs.rewrite(clientDownload.url, source: source)
        else { return }
        let dest = pathProvider.versionDirectory(versionName: versionName)
            .appendingPathComponent("\(versionName).jar")
        if FileManager.default.fileExists(atPath: dest.path) { return }
        try await client.download(from: url, to: dest)
    }

    private func downloadLibraries(_ version: VersionJSON, source: DownloadSourcePreference) async throws {
        let libRoot = pathProvider.minecraftDirectory.appendingPathComponent("libraries", isDirectory: true)
        for library in version.libraries where LibraryRules.allows(library.rules) {
            if let artifact = library.downloads?.artifact {
                let relative = artifact.path ?? MavenCoordinate.path(from: library.name)
                let dest = libRoot.appendingPathComponent(relative)
                if !FileManager.default.fileExists(atPath: dest.path) {
                    let urlString = artifact.url ?? (DownloadSourceURLs.librariesOfficial + relative)
                    if let url = DownloadSourceURLs.rewrite(urlString, source: source) {
                        try await client.download(from: url, to: dest)
                    }
                }
            } else {
                let relative = MavenCoordinate.path(from: library.name)
                let dest = libRoot.appendingPathComponent(relative)
                if !FileManager.default.fileExists(atPath: dest.path) {
                    let urlString = DownloadSourceURLs.librariesOfficial + relative
                    if let url = DownloadSourceURLs.rewrite(urlString, source: source) {
                        try? await client.download(from: url, to: dest)
                    }
                }
            }

            if let natives = library.natives, let classifierTemplate = natives["osx"] ?? natives["macos"] {
                let classifier = classifierTemplate.replacingOccurrences(of: "${arch}", with: nativeArch())
                if let artifact = library.downloads?.classifiers?[classifier] {
                    let relative = artifact.path ?? MavenCoordinate.path(from: library.name, classifier: classifier)
                    let dest = libRoot.appendingPathComponent(relative)
                    if !FileManager.default.fileExists(atPath: dest.path) {
                        let urlString = artifact.url ?? (DownloadSourceURLs.librariesOfficial + relative)
                        if let url = DownloadSourceURLs.rewrite(urlString, source: source) {
                            try await client.download(from: url, to: dest)
                        }
                    }
                }
            }
        }
    }

    private func downloadAssets(
        _ assetIndex: VersionJSON.AssetIndex,
        source: DownloadSourcePreference,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws {
        let indexesDir = pathProvider.minecraftDirectory
            .appendingPathComponent("assets/indexes", isDirectory: true)
        let indexFile = indexesDir.appendingPathComponent("\(assetIndex.id).json")
        if !FileManager.default.fileExists(atPath: indexFile.path) {
            guard let url = DownloadSourceURLs.rewrite(assetIndex.url, source: source) else {
                throw InstallError.missingVersionURL
            }
            try await client.download(from: url, to: indexFile)
        }
        let index = try JSONDecoder.minecraft.decode(AssetIndexJSON.self, from: Data(contentsOf: indexFile))
        let objectsRoot = pathProvider.minecraftDirectory
            .appendingPathComponent("assets/objects", isDirectory: true)
        let total = Double(max(index.objects.count, 1))
        var done = 0.0
        for (_, object) in index.objects {
            let prefix = String(object.hash.prefix(2))
            let dest = objectsRoot.appendingPathComponent(prefix).appendingPathComponent(object.hash)
            done += 1
            if FileManager.default.fileExists(atPath: dest.path) { continue }
            let base = source == .bmclApi ? DownloadSourceURLs.resourcesBmcl : DownloadSourceURLs.resourcesOfficial
            guard let url = URL(string: "\(base)\(prefix)/\(object.hash)") else { continue }
            try await client.download(from: url, to: dest)
            if Int(done) % 40 == 0 {
                progress(LauncherProgress(
                    stage: InstallProgressStages.completingFiles,
                    message: "Downloading assets",
                    percent: 0.5 + 0.4 * (done / total)
                ))
            }
        }
    }

    private func extractNatives(_ version: VersionJSON, versionName: String) async throws {
        let nativesDir = pathProvider.versionDirectory(versionName: versionName)
            .appendingPathComponent("natives", isDirectory: true)
        try FileManager.default.createDirectory(at: nativesDir, withIntermediateDirectories: true)
        let libRoot = pathProvider.minecraftDirectory.appendingPathComponent("libraries", isDirectory: true)

        for library in version.libraries where LibraryRules.allows(library.rules) {
            guard let natives = library.natives else { continue }
            guard let classifierTemplate = natives["osx"] ?? natives["macos"] else { continue }
            let classifier = classifierTemplate.replacingOccurrences(of: "${arch}", with: nativeArch())
            let relative: String
            if let path = library.downloads?.classifiers?[classifier]?.path {
                relative = path
            } else {
                relative = MavenCoordinate.path(from: library.name, classifier: classifier)
            }
            let jar = libRoot.appendingPathComponent(relative)
            guard FileManager.default.fileExists(atPath: jar.path) else { continue }
            try ZipExtractor.extract(jar: jar, to: nativesDir)
        }
    }

    private func nativeArch() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}

public enum InstallError: LocalizedError {
    case missingVersionURL
    case versionNotFound(String)
    case loaderNotFound
    case javaNotFound
    case installerFailed(String)
    case installerOutputMissing

    public var errorDescription: String? {
        switch self {
        case .missingVersionURL: return "Version metadata URL is missing."
        case .versionNotFound(let id): return "Minecraft version \(id) was not found."
        case .loaderNotFound: return "Loader version was not found."
        case .javaNotFound: return "No suitable Java runtime was found."
        case .installerFailed(let detail): return "Loader installer failed: \(detail)"
        case .installerOutputMissing: return "Loader installer did not produce a version directory."
        }
    }
}

enum LibraryRules {
    static func allows(_ rules: [VersionJSON.Rule]?) -> Bool {
        guard let rules, !rules.isEmpty else { return true }
        var allowed = false
        for rule in rules {
            if let features = rule.features, features.values.contains(true) {
                continue
            }
            let osMatch: Bool
            if let osName = rule.os?.name {
                osMatch = osName == "osx" || osName == "macos"
            } else {
                osMatch = true
            }
            if osMatch {
                allowed = rule.action == "allow"
            }
        }
        return allowed
    }
}

enum MavenCoordinate {
    static func path(from name: String, classifier: String? = nil) -> String {
        let parts = name.split(separator: ":").map(String.init)
        guard parts.count >= 3 else { return name }
        let group = parts[0].replacingOccurrences(of: ".", with: "/")
        let artifact = parts[1]
        let version = parts[2]
        if let classifier, !classifier.isEmpty {
            return "\(group)/\(artifact)/\(version)/\(artifact)-\(version)-\(classifier).jar"
        }
        return "\(group)/\(artifact)/\(version)/\(artifact)-\(version).jar"
    }
}
