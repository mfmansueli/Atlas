//
//  CatalogSection.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// One part of the Design System Catalog: its title, what the README
/// says of it, and the specimens.
struct CatalogSection<Content: View>: View {
    let title: String
    var note: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(title)
                    .atlasTextStyle(.title2)
                    .accessibilityAddTraits(.isHeader)
                if let note {
                    Text(note)
                        .atlasTextStyle(.callout)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
    }
}
#endif
