/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmDomain

public enum DownloadSourceURLs {
    public static let officialManifest = URL(string: "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")!
    public static let bmclManifest = URL(string: "https://bmclapi2.bangbang93.com/mc/game/version_manifest_v2.json")!
    public static let fabricMeta = "https://meta.fabricmc.net/v2"
    public static let librariesOfficial = "https://libraries.minecraft.net/"
    public static let librariesBmcl = "https://bmclapi2.bangbang93.com/maven/"
    public static let resourcesOfficial = "https://resources.download.minecraft.net/"
    public static let resourcesBmcl = "https://bmclapi2.bangbang93.com/assets/"

    public static func manifestURL(for source: DownloadSourcePreference) -> URL {
        source == .bmclApi ? bmclManifest : officialManifest
    }

    public static func rewrite(_ urlString: String, source: DownloadSourcePreference) -> URL? {
        guard source == .bmclApi else { return URL(string: urlString) }
        var rewritten = urlString
        rewritten = rewritten.replacingOccurrences(
            of: "https://piston-meta.mojang.com",
            with: "https://bmclapi2.bangbang93.com"
        )
        rewritten = rewritten.replacingOccurrences(
            of: "https://launchermeta.mojang.com",
            with: "https://bmclapi2.bangbang93.com"
        )
        rewritten = rewritten.replacingOccurrences(
            of: "https://launcher.mojang.com",
            with: "https://bmclapi2.bangbang93.com"
        )
        rewritten = rewritten.replacingOccurrences(
            of: librariesOfficial,
            with: librariesBmcl
        )
        rewritten = rewritten.replacingOccurrences(
            of: resourcesOfficial,
            with: resourcesBmcl
        )
        return URL(string: rewritten)
    }
}

public actor HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    public func download(from url: URL, to destination: URL) async throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let (tempURL, response) = try await session.download(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }

    public func json<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let data = try await data(from: url)
        return try JSONDecoder.minecraft.decode(T.self, from: data)
    }
}

extension JSONDecoder {
    static let minecraft: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
