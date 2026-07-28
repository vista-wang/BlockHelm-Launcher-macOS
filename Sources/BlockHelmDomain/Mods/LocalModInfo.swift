/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

public struct LocalModInfo: Identifiable, Sendable, Equatable, Hashable {
    public var id: String { fileName }
    public var fileName: String
    public var filePath: String
    public var isEnabled: Bool
    public var fileSize: Int64

    public init(fileName: String, filePath: String, isEnabled: Bool, fileSize: Int64) {
        self.fileName = fileName
        self.filePath = filePath
        self.isEnabled = isEnabled
        self.fileSize = fileSize
    }

    public var displayName: String {
        fileName
            .replacingOccurrences(of: ".jar.disabled", with: "")
            .replacingOccurrences(of: ".jar", with: "")
    }
}
