/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

public enum LauncherAccountKind: Int, Codable, Sendable, CaseIterable {
    case offline = 0
    case microsoft = 1
    case thirdParty = 2
}

public enum OfflineUuidGenerationMode: Int, Codable, Sendable, CaseIterable {
    case standard = 0
    case random = 1
    case manual = 2
}

public enum MinecraftSkinModel: Int, Codable, Sendable, CaseIterable {
    case classic = 0
    case slim = 1
}

public struct LauncherSkinRecord: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var source: String
    public var skinModel: MinecraftSkinModel
    public var contentHash: String
    public var addedAtUtc: Date

    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case source = "Source"
        case skinModel = "SkinModel"
        case contentHash = "ContentHash"
        case addedAtUtc = "AddedAtUtc"
    }

    public init(
        id: String = UUID().uuidString,
        source: String = "",
        skinModel: MinecraftSkinModel = .classic,
        contentHash: String = "",
        addedAtUtc: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.skinModel = skinModel
        self.contentHash = contentHash
        self.addedAtUtc = addedAtUtc
    }
}

public struct LauncherCapeRecord: Codable, Sendable, Equatable, Identifiable {
    public var id: String?
    public var displayName: String
    public var imageUrl: String?
    public var isActive: Bool
    public var isNone: Bool

    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case displayName = "DisplayName"
        case imageUrl = "ImageUrl"
        case isActive = "IsActive"
        case isNone = "IsNone"
    }

    public init(
        id: String? = nil,
        displayName: String = "",
        imageUrl: String? = nil,
        isActive: Bool = false,
        isNone: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.imageUrl = imageUrl
        self.isActive = isActive
        self.isNone = isNone
    }
}

public struct LauncherAccountRecord: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var displayName: String
    public var kind: LauncherAccountKind?
    public var uuid: String?
    public var authenticationServerUrl: String?
    public var thirdPartyPlatformName: String?
    public var thirdPartyLoginUsername: String?
    public var offlineUuidGenerationMode: OfflineUuidGenerationMode
    public var avatarSource: String?
    public var skinSource: String?
    public var skinModel: MinecraftSkinModel?
    public var skins: [LauncherSkinRecord]
    public var activeSkinId: String?
    public var isOffline: Bool
    public var capes: [LauncherCapeRecord]

    public enum CodingKeys: String, CodingKey {
        case id = "Id"
        case displayName = "DisplayName"
        case kind = "Kind"
        case uuid = "Uuid"
        case authenticationServerUrl = "AuthenticationServerUrl"
        case thirdPartyPlatformName = "ThirdPartyPlatformName"
        case thirdPartyLoginUsername = "ThirdPartyLoginUsername"
        case offlineUuidGenerationMode = "OfflineUuidGenerationMode"
        case avatarSource = "AvatarSource"
        case skinSource = "SkinSource"
        case skinModel = "SkinModel"
        case skins = "Skins"
        case activeSkinId = "ActiveSkinId"
        case isOffline = "IsOffline"
        case capes = "Capes"
    }

    public init(
        id: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
        displayName: String = LauncherDefaults.defaultOfflineUsername,
        kind: LauncherAccountKind? = .offline,
        uuid: String? = nil,
        authenticationServerUrl: String? = nil,
        thirdPartyPlatformName: String? = nil,
        thirdPartyLoginUsername: String? = nil,
        offlineUuidGenerationMode: OfflineUuidGenerationMode = .standard,
        avatarSource: String? = nil,
        skinSource: String? = nil,
        skinModel: MinecraftSkinModel? = .classic,
        skins: [LauncherSkinRecord] = [],
        activeSkinId: String? = nil,
        isOffline: Bool = true,
        capes: [LauncherCapeRecord] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.uuid = uuid
        self.authenticationServerUrl = authenticationServerUrl
        self.thirdPartyPlatformName = thirdPartyPlatformName
        self.thirdPartyLoginUsername = thirdPartyLoginUsername
        self.offlineUuidGenerationMode = offlineUuidGenerationMode
        self.avatarSource = avatarSource
        self.skinSource = skinSource
        self.skinModel = skinModel
        self.skins = skins
        self.activeSkinId = activeSkinId
        self.isOffline = isOffline
        self.capes = capes
    }
}

public struct LauncherAccountState: Codable, Sendable, Equatable {
    public var offlineUsername: String
    public var selectedAccountId: String?
    public var accountsInitialized: Bool
    public var microsoftAccountsImported: Bool
    public var sharedSkinLibraryMigrationVersion: Int
    public var accounts: [LauncherAccountRecord]

    public enum CodingKeys: String, CodingKey {
        case offlineUsername = "OfflineUsername"
        case selectedAccountId = "SelectedAccountId"
        case accountsInitialized = "AccountsInitialized"
        case microsoftAccountsImported = "MicrosoftAccountsImported"
        case sharedSkinLibraryMigrationVersion = "SharedSkinLibraryMigrationVersion"
        case accounts = "Accounts"
    }

    public init(
        offlineUsername: String = LauncherDefaults.defaultOfflineUsername,
        selectedAccountId: String? = nil,
        accountsInitialized: Bool = false,
        microsoftAccountsImported: Bool = false,
        sharedSkinLibraryMigrationVersion: Int = 1,
        accounts: [LauncherAccountRecord] = []
    ) {
        self.offlineUsername = offlineUsername
        self.selectedAccountId = selectedAccountId
        self.accountsInitialized = accountsInitialized
        self.microsoftAccountsImported = microsoftAccountsImported
        self.sharedSkinLibraryMigrationVersion = sharedSkinLibraryMigrationVersion
        self.accounts = accounts
    }

    public var selectedAccount: LauncherAccountRecord? {
        guard let selectedAccountId else { return accounts.first }
        return accounts.first { $0.id == selectedAccountId } ?? accounts.first
    }
}
