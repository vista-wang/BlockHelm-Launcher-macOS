/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

public struct GameInstance: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var minecraftVersion: String
    public var loader: LoaderKind
    public var loaderVersion: String?
    public var versionName: String
    public var versionType: String
    public var description: String
    public var iconSource: String?
    public var instanceDirectory: String
    public var backupDirectory: String
    public var memorySettingsMode: MemorySettingsMode
    public var memoryMb: Int
    public var windowWidth: Int
    public var windowHeight: Int
    public var preLaunchCommand: String
    public var waitForPreLaunchCommand: Bool
    public var postExitCommand: String
    public var jvmArguments: String
    public var gameArguments: String
    public var launchSettingsMode: LaunchSettingsMode
    public var javaSettingsMode: LaunchSettingsMode
    public var javaSelectionMode: JavaSelectionMode
    public var selectedJavaExecutablePath: String?
    public var checkFilesBeforeLaunch: Bool
    public var autoRepairMissingFiles: Bool
    public var minimizeLauncherAfterLaunch: Bool
    public var launchFullScreen: Bool
    public var autoJoinServerAddress: String
    public var createdAt: Date
    public var updatedAt: Date

    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case minecraftVersion = "MinecraftVersion"
        case loader = "Loader"
        case loaderVersion = "LoaderVersion"
        case versionName = "VersionName"
        case versionType = "VersionType"
        case description = "Description"
        case iconSource = "IconSource"
        case instanceDirectory = "InstanceDirectory"
        case backupDirectory = "BackupDirectory"
        case memorySettingsMode = "MemorySettingsMode"
        case memoryMb = "MemoryMb"
        case windowWidth = "WindowWidth"
        case windowHeight = "WindowHeight"
        case preLaunchCommand = "PreLaunchCommand"
        case waitForPreLaunchCommand = "WaitForPreLaunchCommand"
        case postExitCommand = "PostExitCommand"
        case jvmArguments = "JvmArguments"
        case gameArguments = "GameArguments"
        case launchSettingsMode = "LaunchSettingsMode"
        case javaSettingsMode = "JavaSettingsMode"
        case javaSelectionMode = "JavaSelectionMode"
        case selectedJavaExecutablePath = "SelectedJavaExecutablePath"
        case checkFilesBeforeLaunch = "CheckFilesBeforeLaunch"
        case autoRepairMissingFiles = "AutoRepairMissingFiles"
        case minimizeLauncherAfterLaunch = "MinimizeLauncherAfterLaunch"
        case launchFullScreen = "LaunchFullScreen"
        case autoJoinServerAddress = "AutoJoinServerAddress"
        case createdAt = "CreatedAt"
        case updatedAt = "UpdatedAt"
    }

    public init(
        id: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
        name: String = "",
        minecraftVersion: String = "",
        loader: LoaderKind = .vanilla,
        loaderVersion: String? = nil,
        versionName: String = "",
        versionType: String = "",
        description: String = "",
        iconSource: String? = nil,
        instanceDirectory: String = "",
        backupDirectory: String = "",
        memorySettingsMode: MemorySettingsMode = .manual,
        memoryMb: Int = LauncherDefaults.defaultMemoryMb,
        windowWidth: Int = 1280,
        windowHeight: Int = 720,
        preLaunchCommand: String = "",
        waitForPreLaunchCommand: Bool = true,
        postExitCommand: String = "",
        jvmArguments: String = "",
        gameArguments: String = "",
        launchSettingsMode: LaunchSettingsMode = .useGlobal,
        javaSettingsMode: LaunchSettingsMode = .useGlobal,
        javaSelectionMode: JavaSelectionMode = .auto,
        selectedJavaExecutablePath: String? = nil,
        checkFilesBeforeLaunch: Bool = true,
        autoRepairMissingFiles: Bool = true,
        minimizeLauncherAfterLaunch: Bool = false,
        launchFullScreen: Bool = false,
        autoJoinServerAddress: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.minecraftVersion = minecraftVersion
        self.loader = loader
        self.loaderVersion = loaderVersion
        self.versionName = versionName
        self.versionType = versionType
        self.description = description
        self.iconSource = iconSource
        self.instanceDirectory = instanceDirectory
        self.backupDirectory = backupDirectory
        self.memorySettingsMode = memorySettingsMode
        self.memoryMb = memoryMb
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.preLaunchCommand = preLaunchCommand
        self.waitForPreLaunchCommand = waitForPreLaunchCommand
        self.postExitCommand = postExitCommand
        self.jvmArguments = jvmArguments
        self.gameArguments = gameArguments
        self.launchSettingsMode = launchSettingsMode
        self.javaSettingsMode = javaSettingsMode
        self.javaSelectionMode = javaSelectionMode
        self.selectedJavaExecutablePath = selectedJavaExecutablePath
        self.checkFilesBeforeLaunch = checkFilesBeforeLaunch
        self.autoRepairMissingFiles = autoRepairMissingFiles
        self.minimizeLauncherAfterLaunch = minimizeLauncherAfterLaunch
        self.launchFullScreen = launchFullScreen
        self.autoJoinServerAddress = autoJoinServerAddress
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
