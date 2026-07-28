/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmApplication
import BlockHelmDomain

public final class MacLauncherPathProvider: LauncherPathProviding, @unchecked Sendable {
    public let dataDirectory: URL
    public let minecraftDirectory: URL
    public let accountDataDirectory: URL

    public init(
        dataDirectory: URL? = nil,
        minecraftDirectory: URL? = nil,
        accountDataDirectory: URL? = nil
    ) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let root = appSupport.appendingPathComponent(LauncherDefaults.storageDirectoryName, isDirectory: true)
        self.dataDirectory = dataDirectory ?? root
        self.minecraftDirectory = minecraftDirectory ?? root.appendingPathComponent(".minecraft", isDirectory: true)
        self.accountDataDirectory = accountDataDirectory
            ?? root.appendingPathComponent("accounts", isDirectory: true)
        Self.ensureDirectories([self.dataDirectory, self.minecraftDirectory, self.accountDataDirectory])
    }

    public var settingsFileURL: URL {
        dataDirectory.appendingPathComponent("settings.json")
    }

    public var accountStateFileURL: URL {
        accountDataDirectory.appendingPathComponent("account-state.json")
    }

    public func instanceSettingsURL(versionName: String) -> URL {
        versionDirectory(versionName: versionName)
            .appendingPathComponent("BHL", isDirectory: true)
            .appendingPathComponent("instance-settings.json")
    }

    public func versionDirectory(versionName: String) -> URL {
        minecraftDirectory
            .appendingPathComponent("versions", isDirectory: true)
            .appendingPathComponent(versionName, isDirectory: true)
    }

    public func applying(settings: LauncherSettings) -> MacLauncherPathProvider {
        let data = settings.dataDirectory.isEmpty
            ? dataDirectory
            : URL(fileURLWithPath: settings.dataDirectory, isDirectory: true)
        let minecraft = settings.minecraftDirectory.isEmpty
            ? data.appendingPathComponent(".minecraft", isDirectory: true)
            : URL(fileURLWithPath: settings.minecraftDirectory, isDirectory: true)
        return MacLauncherPathProvider(
            dataDirectory: data,
            minecraftDirectory: minecraft,
            accountDataDirectory: accountDataDirectory
        )
    }

    private static func ensureDirectories(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
