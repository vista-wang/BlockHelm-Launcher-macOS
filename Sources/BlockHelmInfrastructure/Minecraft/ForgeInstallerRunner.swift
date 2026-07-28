/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmApplication
import BlockHelmDomain

enum ForgeInstallerRunner {
    static func run(
        javaPath: String,
        installerJar: URL,
        minecraftDirectory: URL
    ) async throws {
        try FileManager.default.createDirectory(at: minecraftDirectory, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaPath)
        process.arguments = [
            "-jar", installerJar.path,
            "--installClient", minecraftDirectory.path
        ]
        process.currentDirectoryURL = installerJar.deletingLastPathComponent()

        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr

        try process.run()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
        }

        if process.terminationStatus != 0 {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: errData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "exit \(process.terminationStatus)"
            throw InstallError.installerFailed(detail)
        }
    }
}
