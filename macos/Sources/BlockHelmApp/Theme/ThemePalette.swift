/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI
import BlockHelmDomain

public enum AppAccent: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case cyan = "Cyan"
    case green = "Green"
    case emerald = "Emerald"
    case purple = "Purple"
    case pink = "Pink"
    case orange = "Orange"
    case amber = "Amber"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .blue: return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .cyan: return Color(red: 0.15, green: 0.75, blue: 0.85)
        case .green: return Color(red: 0.25, green: 0.72, blue: 0.40)
        case .emerald: return Color(red: 0.10, green: 0.65, blue: 0.55)
        case .purple: return Color(red: 0.55, green: 0.40, blue: 0.90)
        case .pink: return Color(red: 0.90, green: 0.35, blue: 0.60)
        case .orange: return Color(red: 0.95, green: 0.50, blue: 0.20)
        case .amber: return Color(red: 0.95, green: 0.70, blue: 0.20)
        }
    }
}

public struct ThemePalette {
    public let background: Color
    public let sidebar: Color
    public let card: Color
    public let primaryText: Color
    public let secondaryText: Color
    public let separator: Color
    public let accent: Color

    public static func resolve(settings: LauncherSettings, colorScheme: ColorScheme) -> ThemePalette {
        let effectiveDark: Bool
        if settings.themeFollowSystem {
            effectiveDark = colorScheme == .dark
        } else {
            effectiveDark = settings.theme.lowercased() != "light"
        }
        let accent = AppAccent(rawValue: settings.accentColor)?.color ?? AppAccent.blue.color
        if effectiveDark {
            return ThemePalette(
                background: Color(red: 0.11, green: 0.12, blue: 0.14),
                sidebar: Color(red: 0.14, green: 0.15, blue: 0.18),
                card: Color(red: 0.17, green: 0.18, blue: 0.21),
                primaryText: Color.white.opacity(0.92),
                secondaryText: Color.white.opacity(0.62),
                separator: Color.white.opacity(0.08),
                accent: accent
            )
        }
        return ThemePalette(
            background: Color(red: 0.95, green: 0.96, blue: 0.97),
            sidebar: Color(red: 0.98, green: 0.98, blue: 0.99),
            card: Color.white,
            primaryText: Color(red: 0.12, green: 0.14, blue: 0.16),
            secondaryText: Color(red: 0.35, green: 0.38, blue: 0.42),
            separator: Color.black.opacity(0.08),
            accent: accent
        )
    }
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.resolve(settings: LauncherSettings(), colorScheme: .dark)
}

extension EnvironmentValues {
    public var themePalette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}
