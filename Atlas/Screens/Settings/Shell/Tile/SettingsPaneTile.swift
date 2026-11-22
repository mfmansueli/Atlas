//
//  SettingsPaneTile.swift
//  Atlas
//

import SwiftUI

/// A Settings pane's white glyph on its colour tile, as System Settings
/// draws its sidebar: 20 pt, radius 6, the symbol at 58%.
struct SettingsPaneTile: View {
    let pane: SettingsPane
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: pane.systemImage)
            .font(.system(size: size * 0.58, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(pane.tileGradient, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(SettingsPane.allCases, id: \.self) { SettingsPaneTile(pane: $0) }
    }
    .padding()
}
