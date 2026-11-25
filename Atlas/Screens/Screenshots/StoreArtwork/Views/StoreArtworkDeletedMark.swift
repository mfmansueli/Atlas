//
//  StoreArtworkDeletedMark.swift
//  Atlas
//

import SwiftUI

/// "Will be deleted" on artwork marked to come off with the next push, as
/// on a screenshot.
struct StoreArtworkDeletedMark: View {
    var body: some View {
        Text("Will be deleted", comment: "kind:status")
            .atlasTextStyle(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.xSmall)
            .padding(.vertical, Spacing.tiny)
            .background(Palette.errMark, in: Capsule())
            .accessibilityHidden(true)
    }
}
