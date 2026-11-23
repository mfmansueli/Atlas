//
//  ConnectTrustNote.swift
//  Atlas
//

import SwiftUI

/// "The key never leaves this Mac…", next to the Connect button.
struct ConnectTrustNote: View {
    var body: some View {
        HStack(alignment: .center, spacing: Spacing.medium) {
            Image(systemName: "lock")
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text("The key never leaves this Mac. Every request is signed here and sent straight to Apple.")
                .font(.footnote)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .help(Text("Each request uses a 15-minute ES256 token signed on this Mac."))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ConnectTrustNote()
        .frame(width: 340)
        .padding()
}
