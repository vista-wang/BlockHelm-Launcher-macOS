/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation
import BlockHelmApplication
import BlockHelmDomain

public final class MacJavaRuntimeDiscoveryService: JavaRuntimeDiscoveryService, @unchecked Sendable {
    public init() {}

    public func discover() async -> [JavaRuntimeInfo] {
        var results: [JavaRuntimeInfo] = []
        var seen = Set<String>()

        // /usr/libexec/java_home -V dumps to stderr
        if let fromJavaHome = runJavaHomeList() {
            for item in fromJavaHome {
                if seen.insert(item.executablePath).inserted {
                    results.append(item)
                }
            }
        }

        let candidates = [
            "/opt/homebrew/opt/openjdk/bin/java",
            "/opt/homebrew/opt/openjdk@21/bin/java",
            "/opt/homebrew/opt/openjdk@17/bin/java",
            "/usr/local/opt/openjdk/bin/java",
            "/Library/Java/JavaVirtualMachines"
        ]

        for path in candidates {
            var isDir: ObjCBool = false
            if path.hasSuffix("JavaVirtualMachines"),
               FileManager.default.fileExists(atPath: path, isDirectory: &isDir),
               isDir.boolValue,
               let children = try? FileManager.default.contentsOfDirectory(atPath: path) {
                for child in children {
                    let java = "\(path)/\(child)/Contents/Home/bin/java"
                    if let info = inspect(executable: java, source: "JVMDirectory"),
                       seen.insert(info.executablePath).inserted {
                        results.append(info)
                    }
                }
            } else if let info = inspect(executable: path, source: "Homebrew"),
                      seen.insert(info.executablePath).inserted {
                results.append(info)
            }
        }

        return results.sorted { ($0.majorVersion ?? 0) > ($1.majorVersion ?? 0) }
    }

    public func resolveExecutable(settings: LauncherSettings, instance: GameInstance?) async -> JavaRuntimeInfo? {
        let mode = instance?.javaSettingsMode == .perInstance
            ? (instance?.javaSelectionMode ?? .auto)
            : settings.javaSelectionMode
        let manualPath = instance?.javaSettingsMode == .perInstance
            ? instance?.selectedJavaExecutablePath
            : settings.selectedJavaExecutablePath

        if mode == .manual, let manualPath, let info = inspect(executable: manualPath, source: "Manual") {
            return info
        }

        let all = await discover()
        return all.first
    }

    private func runJavaHomeList() -> [JavaRuntimeInfo]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")
        process.arguments = ["-V"]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        var results: [JavaRuntimeInfo] = []
        // Lines like: "    21.0.3 (arm64) \"Oracle Corporation\" - \"OpenJDK 21.0.3\" /Library/Java/..."
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let slash = trimmed.lastIndex(of: "/") else { continue }
            let home = String(trimmed[slash...])
            let java = home.hasSuffix("/bin/java") ? home : home + "/bin/java"
            if let info = inspect(executable: java, source: "java_home") {
                results.append(info)
            }
        }
        return results
    }

    private func inspect(executable: String, source: String) -> JavaRuntimeInfo? {
        let url = URL(fileURLWithPath: executable)
        guard FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
        let process = Process()
        process.executableURL = url
        process.arguments = ["-version"]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let version = parseVersion(from: output)
        let major = parseMajor(from: version)
        let home = url.deletingLastPathComponent().deletingLastPathComponent().path
        let arch = output.contains("aarch64") || output.contains("arm64") ? "arm64" : "x64"
        return JavaRuntimeInfo(
            displayName: "Java \(version ?? "Unknown")",
            version: version,
            majorVersion: major,
            architecture: arch,
            executablePath: url.path,
            installationDirectory: home,
            source: source
        )
    }

    private func parseVersion(from output: String) -> String? {
        // openjdk version "21.0.3" OR java version "1.8.0_402"
        let pattern = #"version \"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              let swiftRange = Range(match.range(at: 1), in: output)
        else { return nil }
        return String(output[swiftRange])
    }

    private func parseMajor(from version: String?) -> Int? {
        guard let version else { return nil }
        if version.hasPrefix("1.") {
            let parts = version.split(separator: ".")
            if parts.count >= 2 { return Int(parts[1]) }
        }
        return Int(version.split(separator: ".").first.map(String.init) ?? "")
    }
}
