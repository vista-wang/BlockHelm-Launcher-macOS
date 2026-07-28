/*
 * BlockHelm Launcher
 * Copyright (C) 2026 Quan Zhou
 * SPDX-License-Identifier: GPL-3.0-only
 */

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var description: String? = nil
    @Environment(\.themePalette) private var palette

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(palette.secondaryText)
            Text(title)
                .font(.title3.weight(.semibold))
            if let description {
                Text(description)
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
