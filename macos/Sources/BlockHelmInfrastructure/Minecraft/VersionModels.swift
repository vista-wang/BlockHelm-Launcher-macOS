/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmApplication
import BlockHelmDomain

struct VersionManifestDTO: Decodable {
    struct Latest: Decodable {
        let release: String
        let snapshot: String
    }

    struct Version: Decodable {
        let id: String
        let type: String
        let url: String
        let time: String?
        let releaseTime: String?
        let sha1: String?
    }

    let latest: Latest
    let versions: [Version]
}

public struct VersionJSON: Decodable, Sendable {
    public struct Download: Decodable, Sendable {
        public let sha1: String?
        public let size: Int?
        public let url: String
    }

    public struct Downloads: Decodable, Sendable {
        public let client: Download?
        public let server: Download?
    }

    public struct LibraryDownloads: Decodable, Sendable {
        public struct Artifact: Decodable, Sendable {
            public let path: String?
            public let sha1: String?
            public let size: Int?
            public let url: String?
        }

        public let artifact: Artifact?
        public let classifiers: [String: Artifact]?
    }

    public struct RuleOS: Decodable, Sendable {
        public let name: String?
        public let arch: String?
    }

    public struct Rule: Decodable, Sendable {
        public let action: String
        public let os: RuleOS?
        public let features: [String: Bool]?
    }

    public struct Native: Decodable, Sendable {
        // classifier map values are strings in older formats
    }

    public struct Library: Decodable, Sendable {
        public let name: String
        public let downloads: LibraryDownloads?
        public let rules: [Rule]?
        public let natives: [String: String]?
    }

    public struct AssetIndex: Decodable, Sendable {
        public let id: String
        public let sha1: String?
        public let size: Int?
        public let totalSize: Int?
        public let url: String
    }

    public struct Arguments: Decodable, Sendable {
        public let game: [ArgumentValue]?
        public let jvm: [ArgumentValue]?
    }

    public enum ArgumentValue: Decodable, Sendable {
        case string(String)
        case object(ArgumentObject)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .string(string)
                return
            }
            self = .object(try container.decode(ArgumentObject.self))
        }

        public var stringValue: String? {
            if case .string(let value) = self { return value }
            return nil
        }
    }

    public struct ArgumentObject: Decodable, Sendable {
        public let rules: [Rule]?
        public let value: ArgumentStringOrArray?
    }

    public enum ArgumentStringOrArray: Decodable, Sendable {
        case string(String)
        case array([String])

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .string(string)
                return
            }
            self = .array(try container.decode([String].self))
        }

        public var values: [String] {
            switch self {
            case .string(let value): return [value]
            case .array(let values): return values
            }
        }
    }

    public let id: String
    public let mainClass: String
    public let type: String?
    public let minecraftArguments: String?
    public let arguments: Arguments?
    public let libraries: [Library]
    public let downloads: Downloads?
    public let assetIndex: AssetIndex?
    public let assets: String?
    public let inheritsFrom: String?
    public let jar: String?
}

struct AssetIndexJSON: Decodable {
    struct Object: Decodable {
        let hash: String
        let size: Int
    }

    let objects: [String: Object]
}

public final class MojangGameVersionService: GameVersionService, @unchecked Sendable {
    private let client: HTTPClient
    private let pathProvider: LauncherPathProviding

    public init(client: HTTPClient = HTTPClient(), pathProvider: LauncherPathProviding) {
        self.client = client
        self.pathProvider = pathProvider
    }

    public func listVersions(
        source: DownloadSourcePreference,
        includeSnapshots: Bool
    ) async throws -> [MinecraftVersionInfo] {
        let manifest = try await client.json(VersionManifestDTO.self, from: DownloadSourceURLs.manifestURL(for: source))
        let installed = Set(installedVersionNames())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()

        return manifest.versions.compactMap { version in
            if !includeSnapshots && version.type != "release" {
                return nil
            }
            let releaseTime = version.releaseTime.flatMap { formatter.date(from: $0) ?? fallback.date(from: $0) }
            return MinecraftVersionInfo(
                name: version.id,
                type: version.type,
                isInstalled: installed.contains(version.id),
                releaseTime: releaseTime,
                url: version.url
            )
        }
    }

    private func installedVersionNames() -> [String] {
        let root = pathProvider.minecraftDirectory.appendingPathComponent("versions", isDirectory: true)
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: root.path) else { return [] }
        return dirs
    }
}
