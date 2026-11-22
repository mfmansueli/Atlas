//
//  ScreenshotHandNote.swift
//  Atlas
//

import SwiftUI

/// A note in a sheet of Screenshots by hand: neutral, or a warning for
/// what a delete leaves.
struct ScreenshotHandNote: View {
    let text: String
    var isWarning = false

    var body: some View {
        Text(text)
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .background(isWarning ? Palette.warningTint : Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner))
            .accessibilityIdentifier("screenshots.hand.note")
    }
}
