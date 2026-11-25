//
//  HelpDownloadPage.swift
//  Atlas
//

import SwiftUI

/// Step 3's picture: Download in the key's row, in the ring, and the key
/// file it saves.
struct HelpDownloadPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HelpKeyTable(ring: .download)
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: "key")
                    .foregroundStyle(Palette.label2)
                Text(verbatim: "AuthKey_\(HelpDrawing.sampleKeyID).p8")
                    .atlasTextStyle(.footnote)
                    .fontDesign(.monospaced)
                Text("in Downloads", comment: "kind:label")
                    .foregroundStyle(Palette.label2)
            }
            .padding(.vertical, Spacing.xSmall)
            .padding(.horizontal, Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
            .padding(.horizontal, Spacing.medium)
        }
    }
}
