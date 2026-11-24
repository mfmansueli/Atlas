//
//  HelpShownBanner.swift
//  Atlas
//

import SwiftUI

/// After Show Me: "Opened Settings → Accounts in Atlas."
struct HelpShownBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "arrow.up.right.square")
            .font(.callout)
            .padding(Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.accentTint, in: RoundedRectangle(cornerRadius: Radius.field))
            .accessibilityIdentifier("help.shown")
    }
}
