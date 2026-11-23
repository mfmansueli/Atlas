//
//  InterfaceChip.swift
//  Atlas
//

import SwiftUI

/// "UI" on a thumbnail whose capture shows the primary locale's interface.
struct InterfaceChip: View {
    var body: some View {
        Text("UI")
            .font(.footnote.weight(.bold).monospaced())
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(Palette.warnMark, in: RoundedRectangle(cornerRadius: Radius.flag, style: .continuous))
            .accessibilityHidden(true)
    }
}
