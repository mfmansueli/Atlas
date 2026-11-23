//
//  CatalogTypeSection.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The ten text styles, each in its own style, with its size, line and
/// weight.
struct CatalogTypeSection: View {
    var body: some View {
        CatalogSection(title: "Type", note: "The macOS text styles. Nothing under 10 pt; 10 pt only for counters and timestamps.") {
            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(AtlasTextStyle.allCases, id: \.self) { style in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.medium) {
                        Text(verbatim: "\(Int(style.size)) / \(Int(style.lineHeight)) · \(style.weightName)")
                            .atlasTextStyle(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Palette.label2)
                            .frame(width: 140, alignment: .leading)
                        Text(style.title)
                            .atlasTextStyle(style)
                    }
                }
            }
        }
    }
}
#endif
