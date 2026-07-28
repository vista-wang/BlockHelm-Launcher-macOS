/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import CryptoKit
import BlockHelmApplication
import BlockHelmDomain

public final class CurseForgeServiceImpl: CurseForgeService, @unchecked Sendable {
    private let client: HTTPClient
    private let keyResolver: CurseForgeApiKeyResolver
    private let baseURL = URL(string: "https://api.curseforge.com/v1")!
    private let gameId = 432

    public init(client: HTTPClient, keyResolver: CurseForgeApiKeyResolver) {
        self.client = client
        self.keyResolver = keyResolver
    }

    public var isConfigured: Bool { keyResolver.resolve() != nil }

    public func searchProjects(
        query: String,
        kind: ModrinthProjectKind,
        minecraftVersion: String,
        loader: LoaderKind
    ) async throws -> [ModrinthProject] {
        guard let apiKey = keyResolver.resolve() else {
            throw CurseForgeError.apiKeyMissing
        }

        var items: [URLQueryItem] = [
            URLQueryItem(name: "gameId", value: "\(gameId)"),
            URLQueryItem(name: "classId", value: "\(classId(for: kind))"),
            URLQueryItem(name: "sortField", value: "6"),
            URLQueryItem(name: "sortOrder", value: "desc"),
            URLQueryItem(name: "pageSize", value: "24"),
            URLQueryItem(name: "index", value: "0")
        ]
        if !query.isEmpty {
            items.append(URLQueryItem(name: "searchFilter", value: query))
        }
        if !minecraftVersion.isEmpty {
            items.append(URLQueryItem(name: "gameVersion", value: minecraftVersion))
        }
        if kind == .mod, let loaderType = modLoaderType(loader) {
            items.append(URLQueryItem(name: "modLoaderType", value: "\(loaderType)"))
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("mods/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("BHL/0.1 (BlockHelm-Launcher-macOS)", forHTTPHeaderField: "User-Agent")
        let (data, http) = try await client.data(for: request)
        if http.statusCode == 401 || http.statusCode == 403 {
            throw CurseForgeError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        return response.data.map {
            ModrinthProject(
                projectId: String($0.id),
                slug: $0.slug ?? "",
                title: $0.name ?? $0.slug ?? String($0.id),
                description: $0.summary ?? "",
                iconUrl: $0.logo?.thumbnailUrl ?? $0.logo?.url,
                downloads: $0.downloadCount ?? 0,
                kind: kind
            )
        }
    }

    public func installLatestCompatible(
        project: ModrinthProject,
        instance: GameInstance,
        installDependencies: Bool,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> [String] {
        guard let apiKey = keyResolver.resolve() else {
            throw CurseForgeError.apiKeyMissing
        }
        guard let projectId = Int(project.projectId) else {
            throw CurseForgeError.invalidProjectId(project.projectId)
        }

        var installed: [String] = []
        var visited = Set<Int>()
        try await installRecursive(
            projectId: projectId,
            title: project.title,
            kind: project.kind,
            instance: instance,
            installDependencies: installDependencies,
            apiKey: apiKey,
            visited: &visited,
            installed: &installed,
            progress: progress,
            depth: 0
        )
        progress(LauncherProgress(
            stage: InstallProgressStages.finalizingVersion,
            message: "Installed \(installed.count) file(s)",
            percent: 1
        ))
        return installed
    }

    private func installRecursive(
        projectId: Int,
        title: String,
        kind: ModrinthProjectKind,
        instance: GameInstance,
        installDependencies: Bool,
        apiKey: String,
        visited: inout Set<Int>,
        installed: inout [String],
        progress: @escaping @Sendable (LauncherProgress) -> Void,
        depth: Int
    ) async throws {
        guard visited.insert(projectId).inserted else { return }
        guard depth < 8 else { return }

        progress(LauncherProgress(
            stage: InstallProgressStages.preparing,
            message: "Resolving \(title)",
            percent: min(0.1 + Double(depth) * 0.1, 0.8)
        ))

        let files = try await listFiles(
            projectId: projectId,
            minecraftVersion: instance.minecraftVersion,
            loader: kind == .mod ? instance.loader : nil,
            apiKey: apiKey
        )
        guard let selected = files.first else {
            throw CurseForgeError.noCompatibleFile(String(projectId), instance.minecraftVersion, instance.loader)
        }

        if installDependencies, kind == .mod {
            for dep in selected.dependencies ?? [] where dep.relationType == 3 {
                guard let depId = dep.modId, depId > 0 else { continue }
                try await installRecursive(
                    projectId: depId,
                    title: String(depId),
                    kind: .mod,
                    instance: instance,
                    installDependencies: true,
                    apiKey: apiKey,
                    visited: &visited,
                    installed: &installed,
                    progress: progress,
                    depth: depth + 1
                )
            }
        }

        let downloadURL = try await resolveDownloadURL(projectId: projectId, file: selected, apiKey: apiKey)
        let fileName = selected.fileName ?? downloadURL.lastPathComponent
        progress(LauncherProgress(
            stage: InstallProgressStages.completingFiles,
            message: "Downloading \(fileName)",
            percent: min(0.4 + Double(depth) * 0.1, 0.9)
        ))

        if kind == .world {
            let path = try await installWorldArchive(
                from: downloadURL,
                preferredName: title,
                instance: instance,
                client: client
            )
            installed.append(path)
            return
        }

        let folder = URL(fileURLWithPath: instance.instanceDirectory)
            .appendingPathComponent(kind.folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            installed.append(destination.path)
            return
        }
        try await client.download(from: downloadURL, to: destination)

        if let sha1 = selected.hashes?.first(where: { $0.algo == 1 })?.value, !sha1.isEmpty {
            let data = try Data(contentsOf: destination)
            let digest = Insecure.SHA1.hash(data: data)
            let actual = digest.map { String(format: "%02x", $0) }.joined()
            if actual != sha1.lowercased() {
                try? FileManager.default.removeItem(at: destination)
                throw CurseForgeError.checksumMismatch(fileName)
            }
        }
        installed.append(destination.path)
    }

    private func listFiles(
        projectId: Int,
        minecraftVersion: String,
        loader: LoaderKind?,
        apiKey: String
    ) async throws -> [FileDTO] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "pageSize", value: "50"),
            URLQueryItem(name: "index", value: "0"),
            URLQueryItem(name: "sortField", value: "1"),
            URLQueryItem(name: "sortOrder", value: "desc")
        ]
        if !minecraftVersion.isEmpty {
            items.append(URLQueryItem(name: "gameVersion", value: minecraftVersion))
        }
        if let loader, let loaderType = modLoaderType(loader) {
            items.append(URLQueryItem(name: "modLoaderType", value: "\(loaderType)"))
        }
        var components = URLComponents(
            url: baseURL.appendingPathComponent("mods/\(projectId)/files"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        let (data, http) = try await client.data(for: request)
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(FilesResponse.self, from: data).data
    }

    private func resolveDownloadURL(projectId: Int, file: FileDTO, apiKey: String) async throws -> URL {
        if let raw = file.downloadUrl, let url = URL(string: raw) {
            return url
        }
        var request = URLRequest(
            url: baseURL.appendingPathComponent("mods/\(projectId)/files/\(file.id)/download-url")
        )
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        let (data, http) = try await client.data(for: request)
        if (200...299).contains(http.statusCode),
           let payload = try? JSONDecoder().decode(DownloadURLResponse.self, from: data),
           let raw = payload.data,
           let url = URL(string: raw) {
            return url
        }
        if let name = file.fileName {
            let id = file.id
            if let edge = URL(string: "https://edge.forgecdn.net/files/\(id / 1000)/\(id % 1000)/\(name)") {
                return edge
            }
        }
        throw CurseForgeError.downloadURLMissing(file.id)
    }

    private func classId(for kind: ModrinthProjectKind) -> Int {
        switch kind {
        case .mod: return 6
        case .resourcepack: return 12
        case .world: return 17
        case .shader: return 6552
        }
    }

    private func modLoaderType(_ loader: LoaderKind) -> Int? {
        switch loader {
        case .forge: return 1
        case .fabric: return 4
        case .quilt: return 5
        case .neoForge: return 6
        case .vanilla: return nil
        }
    }

    private struct SearchResponse: Decodable {
        let data: [ModDTO]
    }

    private struct FilesResponse: Decodable {
        let data: [FileDTO]
    }

    private struct DownloadURLResponse: Decodable {
        let data: String?
    }

    private struct ModDTO: Decodable {
        let id: Int
        let name: String?
        let slug: String?
        let summary: String?
        let downloadCount: Int?
        let logo: LogoDTO?
        struct LogoDTO: Decodable {
            let url: String?
            let thumbnailUrl: String?
        }
    }

    private struct FileDTO: Decodable {
        let id: Int
        let fileName: String?
        let downloadUrl: String?
        let hashes: [HashDTO]?
        let dependencies: [DependencyDTO]?
        struct HashDTO: Decodable {
            let value: String
            let algo: Int
        }
        struct DependencyDTO: Decodable {
            let modId: Int?
            let relationType: Int?
        }
    }
}

enum WorldInstallHelper {
    static func installWorldArchive(
        from downloadURL: URL,
        preferredName: String,
        instance: GameInstance,
        client: HTTPClient
    ) async throws -> String {
        let saves = URL(fileURLWithPath: instance.instanceDirectory)
            .appendingPathComponent("saves", isDirectory: true)
        try FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)
        let tempZip = FileManager.default.temporaryDirectory
            .appendingPathComponent("bhl-world-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: tempZip) }
        try await client.download(from: downloadURL, to: tempZip)

        let baseName = sanitize(preferredName.isEmpty ? downloadURL.deletingPathExtension().lastPathComponent : preferredName)
        var destination = saves.appendingPathComponent(baseName, isDirectory: true)
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = saves.appendingPathComponent("\(baseName)-\(suffix)", isDirectory: true)
            suffix += 1
        }

        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("bhl-world-extract-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try ZipExtractor.extractAll(archive: tempZip, to: staging)

        let root = try resolveWorldRoot(in: staging)
        try FileManager.default.moveItem(at: root, to: destination)
        return destination.path
    }

    static func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?*%\"<>|")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "World" : cleaned
    }

    static func resolveWorldRoot(in directory: URL) throws -> URL {
        let fm = FileManager.default
        let levelDat = directory.appendingPathComponent("level.dat")
        if fm.fileExists(atPath: levelDat.path) {
            return directory
        }
        let children = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for child in children {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue,
               fm.fileExists(atPath: child.appendingPathComponent("level.dat").path) {
                return child
            }
        }
        throw CurseForgeError.invalidWorldArchive
    }
}

private func installWorldArchive(
    from downloadURL: URL,
    preferredName: String,
    instance: GameInstance,
    client: HTTPClient
) async throws -> String {
    try await WorldInstallHelper.installWorldArchive(
        from: downloadURL,
        preferredName: preferredName,
        instance: instance,
        client: client
    )
}

public enum CurseForgeError: LocalizedError {
    case apiKeyMissing
    case unauthorized
    case invalidProjectId(String)
    case noCompatibleFile(String, String, LoaderKind)
    case checksumMismatch(String)
    case downloadURLMissing(Int)
    case invalidWorldArchive

    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "CurseForge API key is not configured. Set CURSEFORGE_API_KEY or place curseforge.key under BHL/.local-secrets/."
        case .unauthorized:
            return "CurseForge rejected the API key."
        case .invalidProjectId(let id):
            return "Invalid CurseForge project id: \(id)."
        case .noCompatibleFile(let id, let mc, let loader):
            return "No compatible CurseForge file for \(id) (\(mc) / \(loader.displayName))."
        case .checksumMismatch(let name):
            return "Checksum mismatch for \(name)."
        case .downloadURLMissing(let id):
            return "CurseForge download URL missing for file \(id)."
        case .invalidWorldArchive:
            return "World archive does not contain level.dat."
        }
    }
}
