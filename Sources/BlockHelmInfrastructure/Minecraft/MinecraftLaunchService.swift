/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmApplication
import BlockHelmDomain

public final class MinecraftLaunchService: LaunchService, @unchecked Sendable {
    private let pathProvider: LauncherPathProviding
    private let javaDiscovery: JavaRuntimeDiscoveryService

    public init(pathProvider: LauncherPathProviding, javaDiscovery: JavaRuntimeDiscoveryService) {
        self.pathProvider = pathProvider
        self.javaDiscovery = javaDiscovery
    }

    public func launch(
        instance: GameInstance,
        account: LaunchAccount,
        settings: LauncherSettings,
        progress: @escaping @Sendable (LauncherProgress) -> Void
    ) async throws -> Int32 {
        progress(LauncherProgress(stage: LaunchProgressStages.checkingInstance, message: "Checking instance", percent: 0))
        let versionDir = pathProvider.versionDirectory(versionName: instance.versionName)
        let versionJSONURL = versionDir.appendingPathComponent("\(instance.versionName).json")
        guard FileManager.default.fileExists(atPath: versionJSONURL.path) else {
            throw LaunchError.versionJSONMissing(instance.versionName)
        }

        progress(LauncherProgress(stage: LaunchProgressStages.checkingJava, message: "Resolving Java", percent: 0.2))
        guard let java = await javaDiscovery.resolveExecutable(settings: settings, instance: instance) else {
            throw InstallError.javaNotFound
        }

        let chain = try loadVersionChain(startingAt: versionJSONURL)
        let classpath = try buildClasspath(chain: chain, versionName: instance.versionName)
        let nativesDir = versionDir.appendingPathComponent("natives", isDirectory: true)
        try FileManager.default.createDirectory(at: nativesDir, withIntermediateDirectories: true)

        let mainClass = chain.first?.mainClass ?? "net.minecraft.client.main.Main"
        let assetsId = chain.compactMap(\.assetIndex?.id).first
            ?? chain.compactMap(\.assets).first
            ?? "legacy"
        let gameDir = versionDir
        let assetsDir = pathProvider.minecraftDirectory.appendingPathComponent("assets", isDirectory: true)

        let memoryMb = resolvedMemory(instance: instance, settings: settings)
        var jvmArgs: [String] = [
            "-Xmx\(memoryMb)M",
            "-Xms\(min(512, memoryMb))M",
            "-Djava.library.path=\(nativesDir.path)",
            "-Djna.tmpdir=\(nativesDir.path)",
            "-Dorg.lwjgl.system.SharedLibraryExtractPath=\(nativesDir.path)",
            "-Dio.netty.native.workdir=\(nativesDir.path)",
            "-Dminecraft.launcher.brand=BlockHelm",
            "-Dminecraft.launcher.version=0.9.11-macos",
            "-cp", classpath
        ]

        let extraJvm = resolvedJvmArguments(instance: instance, settings: settings)
        jvmArgs.append(contentsOf: splitArgs(extraJvm))

        // Apply JVM argument templates from version JSON.
        for version in chain.reversed() {
            if let jvm = version.arguments?.jvm {
                for item in jvm {
                    switch item {
                    case .string(let value):
                        jvmArgs.append(contentsOf: splitArgs(replace(
                            value,
                            natives: nativesDir.path,
                            classpath: classpath,
                            launcherName: "BlockHelm",
                            launcherVersion: "0.9.11-macos"
                        )))
                    case .object(let obj):
                        if LibraryRules.allows(obj.rules), let values = obj.value?.values {
                            for value in values {
                                jvmArgs.append(contentsOf: splitArgs(replace(
                                    value,
                                    natives: nativesDir.path,
                                    classpath: classpath,
                                    launcherName: "BlockHelm",
                                    launcherVersion: "0.9.11-macos"
                                )))
                            }
                        }
                    }
                }
            }
        }

        // Deduplicate -cp if templates also added classpath.
        jvmArgs = normalizeJvmArgs(jvmArgs)

        var gameArgs: [String] = []
        if let legacy = chain.compactMap(\.minecraftArguments).first {
            gameArgs = splitArgs(legacy)
        } else {
            for version in chain.reversed() {
                if let game = version.arguments?.game {
                    for item in game {
                        switch item {
                        case .string(let value):
                            gameArgs.append(value)
                        case .object(let obj):
                            if LibraryRules.allows(obj.rules), let values = obj.value?.values {
                                gameArgs.append(contentsOf: values)
                            }
                        }
                    }
                }
            }
        }

        let width = instance.windowWidth
        let height = instance.windowHeight
        let replacements: [String: String] = [
            "${auth_player_name}": account.username,
            "${version_name}": instance.versionName,
            "${game_directory}": gameDir.path,
            "${assets_root}": assetsDir.path,
            "${assets_index_name}": assetsId,
            "${auth_uuid}": account.uuid,
            "${auth_access_token}": account.accessToken,
            "${user_type}": account.userType,
            "${version_type}": instance.versionType.isEmpty ? "release" : instance.versionType,
            "${user_properties}": "{}",
            "${clientid}": "",
            "${auth_xuid}": "",
            "${resolution_width}": String(width),
            "${resolution_height}": String(height)
        ]

        gameArgs = gameArgs.map { arg in
            replacements.reduce(arg) { partial, pair in
                partial.replacingOccurrences(of: pair.key, with: pair.value)
            }
        }
        gameArgs.append(contentsOf: splitArgs(resolvedGameArguments(instance: instance, settings: settings)))

        if instance.launchFullScreen || settings.defaultLaunchFullScreen {
            if !gameArgs.contains("--fullscreen") {
                gameArgs.append("--fullscreen")
            }
        } else {
            if !gameArgs.contains("--width") {
                gameArgs.append(contentsOf: ["--width", String(width), "--height", String(height)])
            }
        }

        progress(LauncherProgress(stage: LaunchProgressStages.preparingProcess, message: "Starting Java", percent: 0.8))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: java.executablePath)
        process.arguments = jvmArgs + [mainClass] + gameArgs
        process.currentDirectoryURL = gameDir

        var env = ProcessInfo.processInfo.environment
        env["JAVA_HOME"] = java.installationDirectory
        process.environment = env

        let logDir = pathProvider.dataDirectory.appendingPathComponent("logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let logFile = logDir.appendingPathComponent("latest-launch.log")
        FileManager.default.createFile(atPath: logFile.path, contents: nil)
        let handle = try FileHandle(forWritingTo: logFile)
        process.standardOutput = handle
        process.standardError = handle

        progress(LauncherProgress(stage: LaunchProgressStages.startingProcess, message: "Game process started", percent: 1))
        try process.run()
        // Do not wait — return 0 to indicate spawn success.
        return 0
    }

    private func loadVersionChain(startingAt url: URL) throws -> [VersionJSON] {
        var chain: [VersionJSON] = []
        var currentURL = url
        var guardCount = 0
        while guardCount < 8 {
            guardCount += 1
            let data = try Data(contentsOf: currentURL)
            let version = try JSONDecoder.minecraft.decode(VersionJSON.self, from: data)
            chain.append(version)
            guard let parent = version.inheritsFrom else { break }
            currentURL = pathProvider.versionDirectory(versionName: parent)
                .appendingPathComponent("\(parent).json")
            if !FileManager.default.fileExists(atPath: currentURL.path) {
                throw LaunchError.versionJSONMissing(parent)
            }
        }
        return chain
    }

    private func buildClasspath(chain: [VersionJSON], versionName: String) throws -> String {
        var paths: [String] = []
        let libRoot = pathProvider.minecraftDirectory.appendingPathComponent("libraries", isDirectory: true)
        var seen = Set<String>()

        for version in chain.reversed() {
            for library in version.libraries where LibraryRules.allows(library.rules) {
                let relative: String
                if let path = library.downloads?.artifact?.path {
                    relative = path
                } else {
                    relative = MavenCoordinate.path(from: library.name)
                }
                let full = libRoot.appendingPathComponent(relative).path
                if seen.insert(full).inserted, FileManager.default.fileExists(atPath: full) {
                    paths.append(full)
                }
            }
        }

        let jarName = chain.compactMap(\.jar).last ?? chain.last?.id ?? versionName
        let clientJar = pathProvider.versionDirectory(versionName: jarName)
            .appendingPathComponent("\(jarName).jar")
        if FileManager.default.fileExists(atPath: clientJar.path) {
            paths.append(clientJar.path)
        } else {
            let fallback = pathProvider.versionDirectory(versionName: versionName)
                .appendingPathComponent("\(versionName).jar")
            if FileManager.default.fileExists(atPath: fallback.path) {
                paths.append(fallback.path)
            }
        }
        return paths.joined(separator: ":")
    }

    private func resolvedMemory(instance: GameInstance, settings: LauncherSettings) -> Int {
        if instance.launchSettingsMode == .perInstance || instance.memorySettingsMode == .manual {
            if instance.memorySettingsMode == .manual {
                return instance.memoryMb
            }
        }
        if settings.defaultMemorySettingsMode == .manual {
            return settings.defaultMemoryMb
        }
        // Auto: half of physical memory capped.
        let totalMb = Int(ProcessInfo.processInfo.physicalMemory / 1_048_576)
        return min(8192, max(2048, totalMb / 2))
    }

    private func resolvedJvmArguments(instance: GameInstance, settings: LauncherSettings) -> String {
        instance.launchSettingsMode == .perInstance ? instance.jvmArguments : settings.defaultJvmArguments
    }

    private func resolvedGameArguments(instance: GameInstance, settings: LauncherSettings) -> String {
        instance.launchSettingsMode == .perInstance ? instance.gameArguments : settings.defaultGameArguments
    }

    private func splitArgs(_ value: String) -> [String] {
        value.split(whereSeparator: { $0.isWhitespace }).map(String.init).filter { !$0.isEmpty }
    }

    private func replace(
        _ template: String,
        natives: String,
        classpath: String,
        launcherName: String,
        launcherVersion: String
    ) -> String {
        template
            .replacingOccurrences(of: "${natives_directory}", with: natives)
            .replacingOccurrences(of: "${classpath}", with: classpath)
            .replacingOccurrences(of: "${launcher_name}", with: launcherName)
            .replacingOccurrences(of: "${launcher_version}", with: launcherVersion)
    }

    private func normalizeJvmArgs(_ args: [String]) -> [String] {
        // Keep first -Xmx/-Xms and a single -cp pair from our explicit args when duplicates appear.
        var result: [String] = []
        var sawXmx = false
        var sawXms = false
        var sawCp = false
        var i = 0
        while i < args.count {
            let arg = args[i]
            if arg.hasPrefix("-Xmx") {
                if sawXmx { i += 1; continue }
                sawXmx = true
            }
            if arg.hasPrefix("-Xms") {
                if sawXms { i += 1; continue }
                sawXms = true
            }
            if arg == "-cp" || arg == "-classpath" {
                if sawCp {
                    i += 2
                    continue
                }
                sawCp = true
                result.append(arg)
                if i + 1 < args.count {
                    result.append(args[i + 1])
                }
                i += 2
                continue
            }
            result.append(arg)
            i += 1
        }
        return result
    }
}

public enum LaunchError: LocalizedError {
    case versionJSONMissing(String)

    public var errorDescription: String? {
        switch self {
        case .versionJSONMissing(let name):
            return "Version metadata for \(name) is missing. Install the version first."
        }
    }
}
