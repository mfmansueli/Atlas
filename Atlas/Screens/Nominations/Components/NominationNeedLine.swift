//
//  NominationNeedLine.swift
//  Atlas
//

import SwiftUI

/// What needs the person, in one line: grey when nothing does, amber for
/// something to fix, blue for what waits in Review & Push, purple for an
/// assistant's suggestion.
struct NominationNeedLine: View {
    let need: NominationNeed

    var body: some View {
        Text(need.text)
            .font(.subheadline.weight(need.tone == .quiet ? .regular : .medium))
            .foregroundStyle(color)
            .lineLimit(2)
            .accessibilityIdentifier("nominations.need")
    }

    private var color: Color {
        switch need.tone {
        case .quiet: Palette.label2
        case .warning: Palette.warn
        case .queued: Palette.accentText
        case .suggested: Palette.ai
        }
    }
}
