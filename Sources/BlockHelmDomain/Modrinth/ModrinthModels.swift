/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

public enum ModrinthProjectKind: String, Sendable, CaseIterable, Hashable {
    case mod
    case resourcepack
    case shader
    case world

    public var folderName: String {
        switch self {
        case .mod: return "mods"
        case .resourcepack: return "resourcepacks"
        case .shader: return "shaderpacks"
        case .world: return "saves"
        }
    }

    public var apiProjectType: String {
        switch self {
        case .mod: return "mod"
        case .resourcepack: return "resourcepack"
        case .shader: return "shader"
        case .world: return "world"
        }
    }
}

public enum ResourceCatalogSource: String, Sendable, CaseIterable, Hashable {
    case modrinth
    case curseForge
}

public struct LocalSave: Identifiable, Sendable, Equatable, Hashable {
    public var id: String { directoryName }
    public var name: String
    public var directoryName: String
    public var fullPath: String
    public var createdAt: Date

    public init(name: String, directoryName: String, fullPath: String, createdAt: Date = Date()) {
        self.name = name
        self.directoryName = directoryName
        self.fullPath = fullPath
        self.createdAt = createdAt
    }
}

public struct ModrinthProject: Identifiable, Sendable, Equatable, Hashable {
    public var id: String { projectId }
    public var projectId: String
    public var slug: String
    public var title: String
    public var description: String
    public var iconUrl: String?
    public var downloads: Int
    public var kind: ModrinthProjectKind

    public init(
        projectId: String,
        slug: String = "",
        title: String,
        description: String = "",
        iconUrl: String? = nil,
        downloads: Int = 0,
        kind: ModrinthProjectKind = .mod
    ) {
        self.projectId = projectId
        self.slug = slug
        self.title = title
        self.description = description
        self.iconUrl = iconUrl
        self.downloads = downloads
        self.kind = kind
    }
}

public struct ModrinthVersionFile: Sendable, Equatable, Hashable {
    public var url: String
    public var filename: String
    public var primary: Bool
    public var sha512: String?

    public init(url: String, filename: String, primary: Bool = true, sha512: String? = nil) {
        self.url = url
        self.filename = filename
        self.primary = primary
        self.sha512 = sha512
    }
}

public struct ModrinthDependency: Sendable, Equatable, Hashable {
    public var projectId: String?
    public var versionId: String?
    public var dependencyType: String

    public init(projectId: String? = nil, versionId: String? = nil, dependencyType: String) {
        self.projectId = projectId
        self.versionId = versionId
        self.dependencyType = dependencyType
    }

    public var isRequired: Bool {
        dependencyType.lowercased() == "required"
    }
}

public struct ModrinthVersionInfo: Identifiable, Sendable, Equatable, Hashable {
    public var id: String
    public var versionNumber: String
    public var name: String
    public var gameVersions: [String]
    public var loaders: [String]
    public var files: [ModrinthVersionFile]
    public var dependencies: [ModrinthDependency]

    public init(
        id: String,
        versionNumber: String,
        name: String = "",
        gameVersions: [String] = [],
        loaders: [String] = [],
        files: [ModrinthVersionFile] = [],
        dependencies: [ModrinthDependency] = []
    ) {
        self.id = id
        self.versionNumber = versionNumber
        self.name = name
        self.gameVersions = gameVersions
        self.loaders = loaders
        self.files = files
        self.dependencies = dependencies
    }

    public var primaryFile: ModrinthVersionFile? {
        files.first(where: \.primary) ?? files.first
    }
}

public struct LocalContentItem: Identifiable, Sendable, Equatable, Hashable {
    public var id: String { fileName }
    public var fileName: String
    public var filePath: String
    public var isEnabled: Bool
    public var fileSize: Int64
    public var kind: ModrinthProjectKind

    public init(
        fileName: String,
        filePath: String,
        isEnabled: Bool,
        fileSize: Int64,
        kind: ModrinthProjectKind
    ) {
        self.fileName = fileName
        self.filePath = filePath
        self.isEnabled = isEnabled
        self.fileSize = fileSize
        self.kind = kind
    }

    public var displayName: String {
        fileName
            .replacingOccurrences(of: ".jar.disabled", with: "")
            .replacingOccurrences(of: ".zip.disabled", with: "")
            .replacingOccurrences(of: ".jar", with: "")
            .replacingOccurrences(of: ".zip", with: "")
    }
}

public struct LanWorldAdvertisement: Identifiable, Sendable, Equatable, Hashable {
    public var id: String { "\(address):\(port)" }
    public var motd: String
    public var address: String
    public var port: Int
    public var discoveredAt: Date

    public init(motd: String, address: String, port: Int, discoveredAt: Date = Date()) {
        self.motd = motd
        self.address = address
        self.port = port
        self.discoveredAt = discoveredAt
    }

    public var joinAddress: String { "\(address):\(port)" }
}
