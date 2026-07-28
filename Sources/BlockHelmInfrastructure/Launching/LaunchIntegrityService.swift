/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmApplication
import BlockHelmDomain

public final class LaunchIntegrityServiceImpl: LaunchIntegrityService, @unchecked Sendable {
    private let pathProvider: LauncherPathProviding
    private let javaDiscovery: JavaRuntimeDiscoveryService

    public init(pathProvider: LauncherPathProviding, javaDiscovery: JavaRuntimeDiscoveryService) {
        self.pathProvider = pathProvider
        self.javaDiscovery = javaDiscovery
    }

    public func validate(instance: GameInstance, settings: LauncherSettings) async throws {
        let versionDir = pathProvider.versionDirectory(versionName: instance.versionName)
        let jsonURL = versionDir.appendingPathComponent("\(instance.versionName).json")
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw LaunchIntegrityError.missingVersionJSON(instance.versionName)
        }

        let jarURL = versionDir.appendingPathComponent("\(instance.versionName).jar")
        // Some Forge/NeoForge installs rely on inherited jars; only require jar when referenced.
        if let data = try? Data(contentsOf: jsonURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let inherits = obj["inheritsFrom"] as? String
            let downloads = obj["downloads"] as? [String: Any]
            let hasClient = downloads?["client"] != nil
            if inherits == nil && hasClient && !FileManager.default.fileExists(atPath: jarURL.path) {
                throw LaunchIntegrityError.missingClientJar(instance.versionName)
            }
        }

        guard await javaDiscovery.resolveExecutable(settings: settings, instance: instance) != nil else {
            throw InstallError.javaNotFound
        }

        let libs = pathProvider.minecraftDirectory.appendingPathComponent("libraries", isDirectory: true)
        if !FileManager.default.fileExists(atPath: libs.path) {
            throw LaunchIntegrityError.missingLibraries
        }
    }
}

public enum LaunchIntegrityError: LocalizedError {
    case missingVersionJSON(String)
    case missingClientJar(String)
    case missingLibraries

    public var errorDescription: String? {
        switch self {
        case .missingVersionJSON(let name):
            return "Version metadata for \(name) is missing. Reinstall the instance."
        case .missingClientJar(let name):
            return "Client jar for \(name) is missing. Reinstall or repair the instance."
        case .missingLibraries:
            return "Minecraft libraries folder is missing. Reinstall game files."
        }
    }
}
