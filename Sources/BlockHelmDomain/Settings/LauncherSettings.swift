/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

public struct LauncherSettings: Codable, Sendable, Equatable {
    public var revision: Int64
    public var isMenuExpanded: Bool
    public var isHomeLaunchMenuPinned: Bool
    public var theme: String
    public var accentColor: String
    public var launcherLanguage: String
    public var enableDiagnosticLogging: Bool
    public var hasAcceptedUserAgreement: Bool
    public var autoSetGameLanguageToLauncherLanguage: Bool
    public var themeFollowSystem: Bool
    public var launcherBackgroundEffect: String
    public var launcherBackgroundOpacityPercent: Int
    public var enableImageBackgroundControlBlur: Bool
    public var updateChannel: LauncherUpdateChannel
    public var dataDirectory: String
    public var minecraftDirectory: String
    public var downloadSourcePreference: DownloadSourcePreference
    public var maximumDownloadConcurrency: Int
    public var downloadSpeedLimitMbPerSecond: Int
    public var defaultMemorySettingsMode: MemorySettingsMode
    public var defaultMemoryMb: Int
    public var javaSelectionMode: JavaSelectionMode
    public var selectedJavaExecutablePath: String?
    public var defaultCheckFilesBeforeLaunch: Bool
    public var defaultAutoRepairMissingFiles: Bool
    public var defaultMinimizeLauncherAfterLaunch: Bool
    public var defaultLaunchFullScreen: Bool
    public var defaultAutoJoinServerAddress: String
    public var defaultPreLaunchCommand: String
    public var defaultWaitForPreLaunchCommand: Bool
    public var defaultPostExitCommand: String
    public var defaultJvmArguments: String
    public var defaultGameArguments: String
    public var defaultInstanceId: String?

    public enum CodingKeys: String, CodingKey {
        case revision = "Revision"
        case isMenuExpanded = "IsMenuExpanded"
        case isHomeLaunchMenuPinned = "IsHomeLaunchMenuPinned"
        case theme = "Theme"
        case accentColor = "AccentColor"
        case launcherLanguage = "LauncherLanguage"
        case enableDiagnosticLogging = "EnableDiagnosticLogging"
        case hasAcceptedUserAgreement = "HasAcceptedUserAgreement"
        case autoSetGameLanguageToLauncherLanguage = "AutoSetGameLanguageToLauncherLanguage"
        case themeFollowSystem = "ThemeFollowSystem"
        case launcherBackgroundEffect = "LauncherBackgroundEffect"
        case launcherBackgroundOpacityPercent = "LauncherBackgroundOpacityPercent"
        case enableImageBackgroundControlBlur = "EnableImageBackgroundControlBlur"
        case updateChannel = "UpdateChannel"
        case dataDirectory = "DataDirectory"
        case minecraftDirectory = "MinecraftDirectory"
        case downloadSourcePreference = "DownloadSourcePreference"
        case maximumDownloadConcurrency = "MaximumDownloadConcurrency"
        case downloadSpeedLimitMbPerSecond = "DownloadSpeedLimitMbPerSecond"
        case defaultMemorySettingsMode = "DefaultMemorySettingsMode"
        case defaultMemoryMb = "DefaultMemoryMb"
        case javaSelectionMode = "JavaSelectionMode"
        case selectedJavaExecutablePath = "SelectedJavaExecutablePath"
        case defaultCheckFilesBeforeLaunch = "DefaultCheckFilesBeforeLaunch"
        case defaultAutoRepairMissingFiles = "DefaultAutoRepairMissingFiles"
        case defaultMinimizeLauncherAfterLaunch = "DefaultMinimizeLauncherAfterLaunch"
        case defaultLaunchFullScreen = "DefaultLaunchFullScreen"
        case defaultAutoJoinServerAddress = "DefaultAutoJoinServerAddress"
        case defaultPreLaunchCommand = "DefaultPreLaunchCommand"
        case defaultWaitForPreLaunchCommand = "DefaultWaitForPreLaunchCommand"
        case defaultPostExitCommand = "DefaultPostExitCommand"
        case defaultJvmArguments = "DefaultJvmArguments"
        case defaultGameArguments = "DefaultGameArguments"
        case defaultInstanceId = "DefaultInstanceId"
    }

    public init(
        revision: Int64 = 0,
        isMenuExpanded: Bool = true,
        isHomeLaunchMenuPinned: Bool = false,
        theme: String = LauncherDefaults.defaultTheme,
        accentColor: String = LauncherDefaults.defaultAccentColor,
        launcherLanguage: String = LauncherDefaults.defaultLauncherLanguage,
        enableDiagnosticLogging: Bool = false,
        hasAcceptedUserAgreement: Bool = false,
        autoSetGameLanguageToLauncherLanguage: Bool = true,
        themeFollowSystem: Bool = true,
        launcherBackgroundEffect: String = LauncherDefaults.defaultLauncherBackgroundEffect,
        launcherBackgroundOpacityPercent: Int = LauncherDefaults.defaultLauncherBackgroundOpacityPercent,
        enableImageBackgroundControlBlur: Bool = LauncherDefaults.defaultEnableImageBackgroundControlBlur,
        updateChannel: LauncherUpdateChannel = LauncherDefaults.defaultUpdateChannel,
        dataDirectory: String = "",
        minecraftDirectory: String = "",
        downloadSourcePreference: DownloadSourcePreference = LauncherDefaults.defaultDownloadSourcePreference,
        maximumDownloadConcurrency: Int = LauncherDefaults.defaultMaximumDownloadConcurrency,
        downloadSpeedLimitMbPerSecond: Int = 0,
        defaultMemorySettingsMode: MemorySettingsMode = .auto,
        defaultMemoryMb: Int = LauncherDefaults.defaultMemoryMb,
        javaSelectionMode: JavaSelectionMode = .auto,
        selectedJavaExecutablePath: String? = nil,
        defaultCheckFilesBeforeLaunch: Bool = true,
        defaultAutoRepairMissingFiles: Bool = true,
        defaultMinimizeLauncherAfterLaunch: Bool = false,
        defaultLaunchFullScreen: Bool = false,
        defaultAutoJoinServerAddress: String = "",
        defaultPreLaunchCommand: String = "",
        defaultWaitForPreLaunchCommand: Bool = true,
        defaultPostExitCommand: String = "",
        defaultJvmArguments: String = "",
        defaultGameArguments: String = "",
        defaultInstanceId: String? = nil
    ) {
        self.revision = revision
        self.isMenuExpanded = isMenuExpanded
        self.isHomeLaunchMenuPinned = isHomeLaunchMenuPinned
        self.theme = theme
        self.accentColor = accentColor
        self.launcherLanguage = launcherLanguage
        self.enableDiagnosticLogging = enableDiagnosticLogging
        self.hasAcceptedUserAgreement = hasAcceptedUserAgreement
        self.autoSetGameLanguageToLauncherLanguage = autoSetGameLanguageToLauncherLanguage
        self.themeFollowSystem = themeFollowSystem
        self.launcherBackgroundEffect = launcherBackgroundEffect
        self.launcherBackgroundOpacityPercent = launcherBackgroundOpacityPercent
        self.enableImageBackgroundControlBlur = enableImageBackgroundControlBlur
        self.updateChannel = updateChannel
        self.dataDirectory = dataDirectory
        self.minecraftDirectory = minecraftDirectory
        self.downloadSourcePreference = downloadSourcePreference
        self.maximumDownloadConcurrency = maximumDownloadConcurrency
        self.downloadSpeedLimitMbPerSecond = downloadSpeedLimitMbPerSecond
        self.defaultMemorySettingsMode = defaultMemorySettingsMode
        self.defaultMemoryMb = defaultMemoryMb
        self.javaSelectionMode = javaSelectionMode
        self.selectedJavaExecutablePath = selectedJavaExecutablePath
        self.defaultCheckFilesBeforeLaunch = defaultCheckFilesBeforeLaunch
        self.defaultAutoRepairMissingFiles = defaultAutoRepairMissingFiles
        self.defaultMinimizeLauncherAfterLaunch = defaultMinimizeLauncherAfterLaunch
        self.defaultLaunchFullScreen = defaultLaunchFullScreen
        self.defaultAutoJoinServerAddress = defaultAutoJoinServerAddress
        self.defaultPreLaunchCommand = defaultPreLaunchCommand
        self.defaultWaitForPreLaunchCommand = defaultWaitForPreLaunchCommand
        self.defaultPostExitCommand = defaultPostExitCommand
        self.defaultJvmArguments = defaultJvmArguments
        self.defaultGameArguments = defaultGameArguments
        self.defaultInstanceId = defaultInstanceId
    }
}
