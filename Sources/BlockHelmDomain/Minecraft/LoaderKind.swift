/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import Foundation

public enum LoaderKind: Int, Codable, Sendable, CaseIterable, Hashable {
    case vanilla = 0
    case fabric = 1
    case forge = 2
    case neoForge = 3
    case quilt = 4

    public var displayName: String {
        switch self {
        case .vanilla: return "Vanilla"
        case .fabric: return "Fabric"
        case .forge: return "Forge"
        case .neoForge: return "NeoForge"
        case .quilt: return "Quilt"
        }
    }
}
