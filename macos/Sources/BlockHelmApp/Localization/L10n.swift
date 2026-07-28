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
