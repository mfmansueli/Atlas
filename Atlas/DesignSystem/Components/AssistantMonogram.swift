//
//  AssistantMonogram.swift
//  Atlas
//

import SwiftUI

/// An assistant's two-letter tile, e.g. "CC" for Claude Code: label-colored,
/// so it reads in light, dark and Increase Contrast. Assistant chips, source
/// tags and the toolbar indicator start with it.
struct AssistantMonogram: View {
    let letters: String

    var body: some View {
        Text(letters)
            .font(.footnote.weight(.bold))
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            .frame(width: 16, height: 16)
            .background(Palette.label, in: RoundedRectangle(cornerRadius: Radius.flag, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        AssistantMonogram(letters: "CC")
        AssistantMonogram(letters: "CU")
    }
    .padding()
}
