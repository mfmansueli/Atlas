//
//  HelpIssuerAndKeyIDPage.swift
//  Atlas
//

import SwiftUI

/// Step 4's picture: the Issuer ID at the top of Team Keys and the Key ID
/// in the key's row, both in the ring.
struct HelpIssuerAndKeyIDPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.medium) {
                Text(AppStoreConnectPageWords.issuerID)
                    .foregroundStyle(Palette.label2)
                Text(verbatim: HelpDrawing.sampleIssuerID)
                    .atlasTextStyle(.footnote)
                    .fontDesign(.monospaced)
                    .helpPictureRing()
                Text(AppStoreConnectPageWords.copy)
                    .foregroundStyle(Palette.accentText)
            }
            .fixedSize()
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.tiny)
            HelpKeyTable(ring: .keyID)
        }
    }
}
