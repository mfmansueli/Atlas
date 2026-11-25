//
//  StoreArtworkInSearchMark.swift
//  Atlas
//

import SwiftUI

/// "In search" under screenshots 1–3 on iPhone: what search results show
/// when there's no search artwork.
struct StoreArtworkInSearchMark: View {
    var body: some View {
        Label {
            Text("In search", comment: "kind:label")
        } icon: {
            Image(systemName: "magnifyingglass")
        }
        .labelStyle(.titleAndIcon)
        .atlasTextStyle(.subheadline)
        .foregroundStyle(Palette.label2)
        .accessibilityIdentifier("screenshots.page.inSearch")
    }
}
