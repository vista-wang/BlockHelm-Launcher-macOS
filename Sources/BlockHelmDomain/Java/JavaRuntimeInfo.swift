/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

public struct JavaRuntimeInfo: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var displayName: String
    public var version: String?
    public var majorVersion: Int?
    public var architecture: String
    public var executablePath: String
    public var installationDirectory: String
    public var source: String

    public var id: String { executablePath }

    public init(
        displayName: String,
        version: String? = nil,
        majorVersion: Int? = nil,
        architecture: String = "aarch64",
        executablePath: String,
        installationDirectory: String,
        source: String
    ) {
        self.displayName = displayName
        self.version = version
        self.majorVersion = majorVersion
        self.architecture = architecture
        self.executablePath = executablePath
        self.installationDirectory = installationDirectory
        self.source = source
    }
}
