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

    public func searchMods(
        query: String,
        minecraftVersion: String,
        loader: LoaderKind
    ) async throws -> [ModrinthProject] {
        var facets: [[String]] = [["project_type:mod"]]
        if !minecraftVersion.isEmpty {
            facets.append(["versions:\(minecraftVersion)"])
        }
        if loader != .vanilla {
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
                downloads: $0.downloads ?? 0
            )
        }
    }

    public func installLatestCompatible(
        project: ModrinthProject,
        instance: GameInstance,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> String {
        let loader = instance.loader == .vanilla ? "fabric" : instance.loader.catalogSlug
        progress(LauncherProgress(stage: InstallProgressStages.preparing, message: "Resolving \(project.title)", percent: 0.1))
        let versions = try await compatibleVersions(
            projectId: project.projectId,
            minecraftVersion: instance.minecraftVersion,
            loader: loader
        )
        guard let selected = versions.first(where: { !$0.files.isEmpty }),
              let file = selected.primaryFile,
              let fileURL = URL(string: file.url)
        else {
            throw ModrinthError.noCompatibleFile(project.projectId, instance.minecraftVersion, instance.loader)
        }

        let modsDir = URL(fileURLWithPath: instance.instanceDirectory)
            .appendingPathComponent("mods", isDirectory: true)
        try FileManager.default.createDirectory(at: modsDir, withIntermediateDirectories: true)
        let destination = modsDir.appendingPathComponent(file.filename)

        progress(LauncherProgress(stage: InstallProgressStages.completingFiles, message: "Downloading \(file.filename)", percent: 0.4))
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

        progress(LauncherProgress(stage: InstallProgressStages.finalizingVersion, message: "Installed \(file.filename)", percent: 1))
        return destination.path
    }

    private func compatibleVersions(
        projectId: String,
        minecraftVersion: String,
        loader: String
    ) async throws -> [ModrinthVersionInfo] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("project/\(projectId)/version"),
            resolvingAgainstBaseURL: false
        )!
        let loadersJSON = try String(data: JSONEncoder().encode([loader]), encoding: .utf8) ?? "[]"
        let gamesJSON = try String(data: JSONEncoder().encode([minecraftVersion]), encoding: .utf8) ?? "[]"
        components.queryItems = [
            URLQueryItem(name: "loaders", value: loadersJSON),
            URLQueryItem(name: "game_versions", value: gamesJSON)
        ]
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
        struct FileDTO: Decodable {
            let url: String
            let filename: String
            let primary: Bool?
            let hashes: Hashes?
            struct Hashes: Decodable { let sha512: String? }
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
