/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

public struct DownloadSpeedTelemetry: Codable, Sendable, Equatable {
    public var bytesPerSecond: Int64?

    public init(bytesPerSecond: Int64? = nil) {
        self.bytesPerSecond = bytesPerSecond
    }
}

public struct LauncherProgress: Codable, Sendable, Equatable {
    public var stage: String
    public var message: String
    public var percent: Double?
    public var downloadSpeedTelemetry: DownloadSpeedTelemetry?

    public init(
        stage: String,
        message: String,
        percent: Double? = nil,
        downloadSpeedTelemetry: DownloadSpeedTelemetry? = nil
    ) {
        self.stage = stage
        self.message = message
        self.percent = percent
        self.downloadSpeedTelemetry = downloadSpeedTelemetry
    }
}

public enum LaunchProgressStages {
    public static let checkingInstance = "Launch.CheckingInstance"
    public static let checkingJava = "Launch.CheckingJava"
    public static let preparingProcess = "Launch.PreparingProcess"
    public static let startingProcess = "Launch.StartingProcess"
    public static let checkingFiles = "Files"
    public static let downloadingFiles = "Bytes"
}

public enum InstallProgressStages {
    public static let queue = "Install.Queue"
    public static let preparing = "Install.Preparing"
    public static let checkingJava = "Install.CheckingJava"
    public static let downloadingJava = "Install.DownloadingJava"
    public static let downloadingLoaderInstaller = "Install.DownloadingLoaderInstaller"
    public static let runningLoaderInstaller = "Install.RunningLoaderInstaller"
    public static let completingFiles = "Install.CompletingFiles"
    public static let finalizingVersion = "Install.FinalizingVersion"
}

public enum InstallTaskState: String, Codable, Sendable, CaseIterable {
    case queued
    case running
    case completed
    case failed
    case cancelled
}

public struct InstallTask: Identifiable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var detail: String
    public var state: InstallTaskState
    public var progress: Double
    public var errorMessage: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        detail: String = "",
        state: InstallTaskState = .queued,
        progress: Double = 0,
        errorMessage: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
        self.progress = progress
        self.errorMessage = errorMessage
        self.createdAt = createdAt
    }
}
