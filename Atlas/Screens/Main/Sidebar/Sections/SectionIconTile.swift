//
//  SectionIconTile.swift
//  Atlas
//

import SwiftUI

/// A section's white glyph on its gradient tile (README — Design system §2):
/// 22 pt in the sidebar with a 6 pt radius, 30 pt in Overview rows with 8,
/// the symbol at 58% of the tile, medium weight.
struct SectionIconTile: View {
    let section: AppWorkspaceSection
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: section.systemImage)
            .font(.system(size: size * 0.58, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(section.tileGradient, in: RoundedRectangle(cornerRadius: size >= 28 ? 8 : 6, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(AppWorkspaceSection.allCases) { SectionIconTile(section: $0) }
    }
    .padding()
}
