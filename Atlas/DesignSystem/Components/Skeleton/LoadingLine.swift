//
//  LoadingLine.swift
//  Atlas
//

import SwiftUI

/// The line over a skeleton that says what's loading (README-DS §9: what
/// is loading, not "Loading…", at most six words), e.g. "Reading Lumen's
/// product pages…". Grey, never a spinner beside it.
struct LoadingLine: View {
    let text: String

    var body: some View {
        Text(text)
            .atlasTextStyle(.callout)
            .foregroundStyle(Palette.label2)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }
}

#Preview {
    LoadingLine(text: "Reading 6 apps from Apple…")
        .padding()
}
