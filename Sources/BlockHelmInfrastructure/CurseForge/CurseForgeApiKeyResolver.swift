/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmApplication

/// Resolves CurseForge API keys without logging the secret value.
public final class CurseForgeApiKeyResolver: @unchecked Sendable {
    private let dataDirectory: URL

    public init(dataDirectory: URL) {
        self.dataDirectory = dataDirectory
    }

    public func resolve() -> String? {
        let candidates: [URL] = [
            dataDirectory
                .appendingPathComponent(".local-secrets", isDirectory: true)
                .appendingPathComponent("curseforge.key"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".local-secrets", isDirectory: true)
                .appendingPathComponent("curseforge.key")
        ]
        for url in candidates {
            if let value = try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        if let env = ProcessInfo.processInfo.environment["CURSEFORGE_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }
        return nil
    }
}
