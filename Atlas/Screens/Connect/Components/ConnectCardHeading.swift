//
//  ConnectCardHeading.swift
//  Atlas
//

import SwiftUI

/// The top of each Connect card: its title and, when the window is tall
/// enough, one line under it.
struct ConnectCardHeading: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var showsSubtitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tiny) {
            Text(title)
                .atlasTextStyle(.title3)
                .accessibilityAddTraits(.isHeader)
            if showsSubtitle {
                Text(subtitle)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ConnectCardHeading(title: "Before you start", subtitle: "Make a key in App Store Connect. About two minutes.")
        .padding()
}
