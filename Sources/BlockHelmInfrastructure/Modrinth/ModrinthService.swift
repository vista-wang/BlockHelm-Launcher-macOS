/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import CryptoKit
import BlockHelmApplication
import BlockHelmDomain

public final class ModrinthServiceImpl: ModrinthService, @unchecked Sendable {
    private let client: HTTPClient
    private let baseURL = URL(string: "https://api.modrinth.com/v2")!

    public init(client: HTTPClient = HTTPClient()) {
        self.client = client
    }

    public func searchProjects(
        query: String,
        kind: ModrinthProjectKind,
        minecraftVersion: String,
        loader: LoaderKind
    ) async throws -> [ModrinthProject] {
        var facets: [[String]] = [["project_type:\(kind.apiProjectType)"]]
        if !minecraftVersion.isEmpty {
            facets.append(["versions:\(minecraftVersion)"])
        }
        if kind == .mod, loader != .vanilla {
            facets.append(["categories:\(loader.catalogSlug)"])
        }
        let facetsJSON = try String(data: JSONEncoder().encode(facets), encoding: .utf8) ?? "[]"
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "24"),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "facets", value: facetsJSON)
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("BHL/0.1 (BlockHelm-Launcher-macOS)", forHTTPHeaderField: "User-Agent")
        let (data, http) = try await client.data(for: request)
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        return response.hits.map {
            ModrinthProject(
                projectId: $0.project_id,
                slug: $0.slug ?? "",
                title: $0.title ?? $0.slug ?? $0.project_id,
                description: $0.description ?? "",
                iconUrl: $0.icon_url,
                downloads: $0.downloads ?? 0,
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
        var installed: [String] = []
        var visited = Set<String>()
        try await installRecursive(
            projectId: project.projectId,
            title: project.title,
            kind: project.kind,
            instance: instance,
            installDependencies: installDependencies,
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
        projectId: String,
        title: String,
        kind: ModrinthProjectKind,
        instance: GameInstance,
        installDependencies: Bool,
        visited: inout Set<String>,
        installed: inout [String],
        progress: @escaping @Sendable (LauncherProgress) -> Void,
        depth: Int
    ) async throws {
        guard visited.insert(projectId).inserted else { return }
        guard depth < 8 else { return }

        let loader = instance.loader == .vanilla ? "fabric" : instance.loader.catalogSlug
        progress(LauncherProgress(
            stage: InstallProgressStages.preparing,
            message: "Resolving \(title)",
            percent: min(0.1 + Double(depth) * 0.1, 0.8)
        ))

        let versions = try await compatibleVersions(
            projectId: projectId,
            minecraftVersion: instance.minecraftVersion,
            loader: kind == .mod ? loader : nil
        )
        guard let selected = versions.first(where: { !$0.files.isEmpty }),
              let file = selected.primaryFile,
              let fileURL = URL(string: file.url)
        else {
            throw ModrinthError.noCompatibleFile(projectId, instance.minecraftVersion, instance.loader)
        }

        if installDependencies, kind == .mod {
            for dependency in selected.dependencies where dependency.isRequired {
                guard let depProjectId = dependency.projectId, !depProjectId.isEmpty else { continue }
                try await installRecursive(
                    projectId: depProjectId,
                    title: depProjectId,
                    kind: .mod,
                    instance: instance,
                    installDependencies: true,
                    visited: &visited,
                    installed: &installed,
                    progress: progress,
                    depth: depth + 1
                )
            }
        }

        let folder = URL(fileURLWithPath: instance.instanceDirectory)
            .appendingPathComponent(kind.folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(file.filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            installed.append(destination.path)
            return
        }

        progress(LauncherProgress(
            stage: InstallProgressStages.completingFiles,
            message: "Downloading \(file.filename)",
            percent: min(0.4 + Double(depth) * 0.1, 0.9)
        ))
        try await client.download(from: fileURL, to: destination)

        if let expected = file.sha512, !expected.isEmpty {
            let data = try Data(contentsOf: destination)
            let digest = SHA512.hash(data: data)
            let actual = digest.map { String(format: "%02x", $0) }.joined()
            if actual != expected.lowercased() {
                try? FileManager.default.removeItem(at: destination)
                throw ModrinthError.checksumMismatch(file.filename)
            }
        }
        installed.append(destination.path)
    }

    private func compatibleVersions(
        projectId: String,
        minecraftVersion: String,
        loader: String?
    ) async throws -> [ModrinthVersionInfo] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("project/\(projectId)/version"),
            resolvingAgainstBaseURL: false
        )!
        var items: [URLQueryItem] = [
            URLQueryItem(
                name: "game_versions",
                value: try String(data: JSONEncoder().encode([minecraftVersion]), encoding: .utf8) ?? "[]"
            )
        ]
        if let loader {
            items.append(URLQueryItem(
                name: "loaders",
                value: try String(data: JSONEncoder().encode([loader]), encoding: .utf8) ?? "[]"
            ))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("BHL/0.1 (BlockHelm-Launcher-macOS)", forHTTPHeaderField: "User-Agent")
        let (data, http) = try await client.data(for: request)
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let dto = try JSONDecoder().decode([VersionDTO].self, from: data)
        return dto.map { item in
            ModrinthVersionInfo(
                id: item.id,
                versionNumber: item.version_number ?? "",
                name: item.name ?? item.version_number ?? item.id,
                gameVersions: item.game_versions ?? [],
                loaders: item.loaders ?? [],
                files: (item.files ?? []).map {
                    ModrinthVersionFile(
                        url: $0.url,
                        filename: $0.filename,
                        primary: $0.primary ?? false,
                        sha512: $0.hashes?.sha512
                    )
                },
                dependencies: (item.dependencies ?? []).map {
                    ModrinthDependency(
                        projectId: $0.project_id,
                        versionId: $0.version_id,
                        dependencyType: $0.dependency_type ?? "required"
                    )
                }
            )
        }
    }

    private struct SearchResponse: Decodable {
        let hits: [Hit]
        struct Hit: Decodable {
            let project_id: String
            let slug: String?
            let title: String?
            let description: String?
            let icon_url: String?
            let downloads: Int?
        }
    }

    private struct VersionDTO: Decodable {
        let id: String
        let name: String?
        let version_number: String?
        let game_versions: [String]?
        let loaders: [String]?
        let files: [FileDTO]?
        let dependencies: [DependencyDTO]?
        struct FileDTO: Decodable {
            let url: String
            let filename: String
            let primary: Bool?
            let hashes: Hashes?
            struct Hashes: Decodable { let sha512: String? }
        }
        struct DependencyDTO: Decodable {
            let project_id: String?
            let version_id: String?
            let dependency_type: String?
        }
    }
}

public enum ModrinthError: LocalizedError {
    case noCompatibleFile(String, String, LoaderKind)
    case checksumMismatch(String)

    public var errorDescription: String? {
        switch self {
        case .noCompatibleFile(let id, let mc, let loader):
            return "No compatible Modrinth file for \(id) (\(mc) / \(loader.displayName))."
        case .checksumMismatch(let name):
            return "Checksum mismatch for \(name)."
        }
    }
}
