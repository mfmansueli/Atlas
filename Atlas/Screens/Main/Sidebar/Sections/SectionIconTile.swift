//
//  SectionIconTile.swift
//  Atlas
//

import SwiftUI

/// A section's glyph on its colored tile.
struct SectionIconTile: View {
    let section: AppWorkspaceSection
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: section.systemImage)
            .font(.system(size: size * 0.52, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(section.tint, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(AppWorkspaceSection.allCases) { SectionIconTile(section: $0) }
    }
    .padding()
}
