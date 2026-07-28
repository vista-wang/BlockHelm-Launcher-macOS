/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

public struct ModrinthProject: Identifiable, Sendable, Equatable, Hashable {
    public var id: String { projectId }
    public var projectId: String
    public var slug: String
    public var title: String
    public var description: String
    public var iconUrl: String?
    public var downloads: Int

    public init(
        projectId: String,
        slug: String = "",
        title: String,
        description: String = "",
        iconUrl: String? = nil,
        downloads: Int = 0
    ) {
        self.projectId = projectId
        self.slug = slug
        self.title = title
        self.description = description
        self.iconUrl = iconUrl
        self.downloads = downloads
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

public struct ModrinthVersionInfo: Identifiable, Sendable, Equatable, Hashable {
    public var id: String
    public var versionNumber: String
    public var name: String
    public var gameVersions: [String]
    public var loaders: [String]
    public var files: [ModrinthVersionFile]

    public init(
        id: String,
        versionNumber: String,
        name: String = "",
        gameVersions: [String] = [],
        loaders: [String] = [],
        files: [ModrinthVersionFile] = []
    ) {
        self.id = id
        self.versionNumber = versionNumber
        self.name = name
        self.gameVersions = gameVersions
        self.loaders = loaders
        self.files = files
    }

    public var primaryFile: ModrinthVersionFile? {
        files.first(where: \.primary) ?? files.first
    }
}
