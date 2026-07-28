/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

public enum MemorySettingsMode: Int, Codable, Sendable, CaseIterable {
    case auto = 0
    case manual = 1
}

public enum LaunchSettingsMode: Int, Codable, Sendable, CaseIterable {
    case useGlobal = 0
    case perInstance = 1
}

public enum JavaSelectionMode: Int, Codable, Sendable, CaseIterable {
    case auto = 0
    case manual = 1
}

public enum DownloadSourcePreference: Int, Codable, Sendable, CaseIterable {
    case official = 1
    case bmclApi = 2
}

public enum LauncherUpdateChannel: Int, Codable, Sendable, CaseIterable {
    case release = 0
    case beta = 1
}

public enum LauncherDefaults {
    public static let storageDirectoryName = "BHL"
    public static let defaultOfflineUsername = "Player"
    public static let defaultTheme = "Dark"
    public static let defaultAccentColor = "Blue"
    public static let defaultLauncherLanguage = "zh-Hans"
    public static let defaultLauncherBackgroundEffect = "Acrylic"
    public static let defaultLauncherBackgroundOpacityPercent = 85
    public static let defaultEnableImageBackgroundControlBlur = true
    public static let defaultUpdateChannel = LauncherUpdateChannel.release
    public static let defaultDownloadSourcePreference = DownloadSourcePreference.official
    public static let defaultMaximumDownloadConcurrency = 64
    public static let defaultMemoryMb = 4096
    public static let accentColors = ["Blue", "Cyan", "Green", "Emerald", "Purple", "Pink", "Orange", "Amber"]
    public static let supportedLanguages = ["zh-Hans", "zh-Hant", "en", "ja-JP"]
}
