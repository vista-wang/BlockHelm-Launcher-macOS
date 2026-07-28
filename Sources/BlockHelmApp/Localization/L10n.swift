/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

public enum L10n {
    private static var bundle: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }

    public static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    public enum Page {
        public static var account: String { text("Page_Account") }
        public static var home: String { text("Page_Home") }
        public static var download: String { text("Page_Download") }
        public static var install: String { text("Page_Install") }
        public static var gameSettings: String { text("Page_GameSettings") }
        public static var multiplayer: String { text("Page_Multiplayer") }
        public static var resources: String { text("Page_Resources") }
        public static var settings: String { text("Page_Settings") }
    }

    public enum Home {
        public static var launch: String { text("Home_Launch") }
        public static var noInstance: String { text("Home_NoInstance") }
        public static var selectInstance: String { text("Home_SelectInstance") }
        public static var launching: String { text("Home_Launching") }
    }

    public enum Download {
        public static var title: String { text("Download_Title") }
        public static var install: String { text("Download_Install") }
        public static var refresh: String { text("Download_Refresh") }
        public static var showSnapshots: String { text("Download_ShowSnapshots") }
        public static var instanceName: String { text("Download_InstanceName") }
        public static var loader: String { text("Download_Loader") }
        public static var loaderVersion: String { text("Download_LoaderVersion") }
        public static var importMrpack: String { text("Download_ImportMrpack") }

        public static func mrpackInstalled(_ name: String) -> String {
            String(format: text("Download_MrpackInstalled"), name)
        }
    }

    public enum Resources {
        public static var instance: String { text("Resources_Instance") }
        public static var search: String { text("Resources_Search") }
        public static var searchPlaceholder: String { text("Resources_SearchPlaceholder") }
        public static var install: String { text("Resources_Install") }
        public static var mods: String { text("Resources_Mods") }
        public static var resourcePacks: String { text("Resources_ResourcePacks") }
        public static var shaders: String { text("Resources_Shaders") }
        public static var worlds: String { text("Resources_Worlds") }
        public static var kind: String { text("Resources_Kind") }
        public static var source: String { text("Resources_Source") }
        public static var modrinth: String { text("Resources_Modrinth") }
        public static var curseForge: String { text("Resources_CurseForge") }
        public static var noMods: String { text("Resources_NoMods") }
        public static var noContent: String { text("Resources_NoContent") }
        public static var needInstance: String { text("Resources_NeedInstance") }
        public static var installDeps: String { text("Resources_InstallDeps") }
        public static var curseForgeKeyMissing: String { text("Resources_CurseForgeKeyMissing") }

        public static func resultCount(_ count: Int) -> String {
            String(format: text("Resources_ResultCount"), count)
        }

        public static func downloads(_ count: Int) -> String {
            String(format: text("Resources_Downloads"), count)
        }

        public static func installed(_ name: String) -> String {
            String(format: text("Resources_Installed"), name)
        }
    }

    public enum Saves {
        public static var title: String { text("Saves_Title") }
        public static var empty: String { text("Saves_Empty") }
        public static var importZip: String { text("Saves_ImportZip") }

        public static func imported(_ name: String) -> String {
            String(format: text("Saves_Imported"), name)
        }
    }

    public enum Multiplayer {
        public static var scan: String { text("Multiplayer_Scan") }
        public static var stop: String { text("Multiplayer_Stop") }
        public static var hint: String { text("Multiplayer_Hint") }
        public static var empty: String { text("Multiplayer_Empty") }
        public static var copy: String { text("Multiplayer_Copy") }
        public static var terracottaTitle: String { text("Multiplayer_TerracottaTitle") }
        public static var terracottaUnavailable: String { text("Multiplayer_TerracottaUnavailable") }

        public static func found(_ count: Int) -> String {
            String(format: text("Multiplayer_Found"), count)
        }

        public static func copied(_ address: String) -> String {
            String(format: text("Multiplayer_Copied"), address)
        }

        public static var scanning: String { text("Multiplayer_Scanning") }
    }

    public enum Account {
        public static var addOffline: String { text("Account_AddOffline") }
        public static var addMicrosoft: String { text("Account_AddMicrosoft") }
        public static var selected: String { text("Account_Selected") }
        public static var empty: String { text("Account_Empty") }
    }

    public enum Settings {
        public static var general: String { text("Settings_SectionGeneral") }
        public static var download: String { text("Settings_SectionDownload") }
        public static var language: String { text("Settings_SectionLanguage") }
        public static var memory: String { text("Settings_SectionLaunchMemory") }
        public static var java: String { text("Settings_SectionJava") }
        public static var theme: String { text("Settings_SectionTheme") }
        public static var info: String { text("Settings_SectionInfo") }
        public static var followSystem: String { text("Settings_ThemeFollowSystemLabel") }
        public static var save: String { text("Settings_Save") }
    }

    public enum Common {
        public static var loading: String { text("Common_Loading") }
        public static var error: String { text("Common_Error") }
        public static var delete: String { text("Common_Delete") }
        public static var rename: String { text("Common_Rename") }
        public static var comingSoon: String { text("Common_ComingSoon") }
        public static var appName: String { text("Common_AppName") }
    }
}
