/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

public struct MinecraftVersionInfo: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var name: String
    public var type: String
    public var isInstalled: Bool
    public var releaseTime: Date?
    public var url: String?

    public var id: String { name }

    public init(
        name: String,
        type: String,
        isInstalled: Bool = false,
        releaseTime: Date? = nil,
        url: String? = nil
    ) {
        self.name = name
        self.type = type
        self.isInstalled = isInstalled
        self.releaseTime = releaseTime
        self.url = url
    }
}

public struct LoaderVersionInfo: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var version: String
    public var isStable: Bool

    public var id: String { version }

    public init(version: String, isStable: Bool = true) {
        self.version = version
        self.isStable = isStable
    }
}

public struct InstalledGameVersion: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var versionName: String
    public var minecraftVersion: String
    public var versionType: String
    public var loader: LoaderKind
    public var loaderVersion: String?
    public var directory: String
    public var discoveredAt: Date

    public var id: String { versionName }

    public init(
        versionName: String,
        minecraftVersion: String,
        versionType: String,
        loader: LoaderKind = .vanilla,
        loaderVersion: String? = nil,
        directory: String,
        discoveredAt: Date = Date()
    ) {
        self.versionName = versionName
        self.minecraftVersion = minecraftVersion
        self.versionType = versionType
        self.loader = loader
        self.loaderVersion = loaderVersion
        self.directory = directory
        self.discoveredAt = discoveredAt
    }
}
