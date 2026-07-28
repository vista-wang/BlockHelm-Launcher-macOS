/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmApplication
import BlockHelmDomain

public final class LoaderCatalogServiceImpl: LoaderCatalogService, @unchecked Sendable {
    private let client: HTTPClient

    public init(client: HTTPClient = HTTPClient()) {
        self.client = client
    }

    public func listForgeVersions(
        minecraftVersion: String,
        source: DownloadSourcePreference
    ) async throws -> [LoaderVersionInfo] {
        // Prefer BMCL JSON catalog (stable); fall back to Maven metadata filtering.
        if let bmcl = try? await listForgeFromBMCL(minecraftVersion: minecraftVersion), !bmcl.isEmpty {
            return bmcl
        }
        return try await listForgeFromMaven(minecraftVersion: minecraftVersion, source: source)
    }

    public func listNeoForgeVersions(
        minecraftVersion: String,
        source: DownloadSourcePreference
    ) async throws -> [LoaderVersionInfo] {
        if minecraftVersion == "1.20.1" {
            return try await listLegacyNeoForge1201(source: source)
        }
        return try await listModernNeoForge(minecraftVersion: minecraftVersion, source: source)
    }

    private func listForgeFromBMCL(minecraftVersion: String) async throws -> [LoaderVersionInfo] {
        struct Entry: Decodable {
            let version: String?
            let mcversion: String?
        }
        let url = URL(string: "https://bmclapi2.bangbang93.com/forge/minecraft/\(minecraftVersion)")!
        let entries = try await client.json([Entry].self, from: url)
        return entries.compactMap { entry in
            guard let version = entry.version, !version.isEmpty else { return nil }
            let mc = entry.mcversion ?? minecraftVersion
            let relative = "net/minecraftforge/forge/\(mc)-\(version)/forge-\(mc)-\(version)-installer.jar"
            return LoaderVersionInfo(
                version: version,
                minecraftVersion: mc,
                installerURL: DownloadSourceURLs.librariesBmcl + relative
            )
        }
        .sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    private func listForgeFromMaven(
        minecraftVersion: String,
        source: DownloadSourcePreference
    ) async throws -> [LoaderVersionInfo] {
        let metaURL = URL(string: "https://maven.minecraftforge.net/net/minecraftforge/forge/maven-metadata.xml")!
        let data = try await client.data(from: metaURL)
        guard let xml = String(data: data, encoding: .utf8) else { return [] }
        let versions = Self.parseMavenVersions(xml)
            .filter { $0.hasPrefix("\(minecraftVersion)-") }
            .map { full in
                let loader = String(full.dropFirst(minecraftVersion.count + 1))
                let relative = "net/minecraftforge/forge/\(full)/forge-\(full)-installer.jar"
                let base = source == .bmclApi
                    ? DownloadSourceURLs.librariesBmcl
                    : "https://maven.minecraftforge.net/"
                return LoaderVersionInfo(
                    version: loader,
                    minecraftVersion: minecraftVersion,
                    installerURL: base + relative
                )
            }
        return versions.sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    private func listModernNeoForge(
        minecraftVersion: String,
        source: DownloadSourcePreference
    ) async throws -> [LoaderVersionInfo] {
        let metaURL = URL(string: "https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml")!
        let data = try await client.data(from: metaURL)
        guard let xml = String(data: data, encoding: .utf8) else { return [] }
        let prefix = Self.neoForgePrefix(for: minecraftVersion)
        let base = source == .bmclApi
            ? "https://bmclapi2.bangbang93.com/maven/"
            : "https://maven.neoforged.net/releases/"
        return Self.parseMavenVersions(xml)
            .filter { $0.hasPrefix(prefix) }
            .map { version in
                let relative = "net/neoforged/neoforge/\(version)/neoforge-\(version)-installer.jar"
                return LoaderVersionInfo(
                    version: version,
                    minecraftVersion: minecraftVersion,
                    installerURL: base + relative
                )
            }
            .sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    private func listLegacyNeoForge1201(source: DownloadSourcePreference) async throws -> [LoaderVersionInfo] {
        let metaURL = URL(string: "https://maven.neoforged.net/releases/net/neoforged/forge/maven-metadata.xml")!
        let data = try await client.data(from: metaURL)
        guard let xml = String(data: data, encoding: .utf8) else { return [] }
        let base = source == .bmclApi
            ? "https://bmclapi2.bangbang93.com/maven/"
            : "https://maven.neoforged.net/releases/"
        return Self.parseMavenVersions(xml)
            .filter { $0.hasPrefix("1.20.1-") }
            .map { coord in
                let loader = String(coord.dropFirst("1.20.1-".count))
                let relative = "net/neoforged/forge/\(coord)/forge-\(coord)-installer.jar"
                return LoaderVersionInfo(
                    version: loader,
                    minecraftVersion: "1.20.1",
                    installerURL: base + relative
                )
            }
            .sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    /// Maps Minecraft version `1.21.1` → NeoForge prefix `21.1.`.
    static func neoForgePrefix(for minecraftVersion: String) -> String {
        let parts = minecraftVersion.split(separator: ".")
        guard parts.count >= 2, parts[0] == "1" else { return minecraftVersion + "." }
        let major = parts[1]
        let minor = parts.count >= 3 ? parts[2] : "0"
        return "\(major).\(minor)."
    }

    static func parseMavenVersions(_ xml: String) -> [String] {
        var versions: [String] = []
        var search = xml[...]
        while let start = search.range(of: "<version>"),
              let end = search.range(of: "</version>", range: start.upperBound..<search.endIndex) {
            let value = String(search[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { versions.append(value) }
            search = search[end.upperBound...]
        }
        return versions
    }
}
