//
//  SuggestionBadge.swift
//  Atlas
//

import SwiftUI

/// The purple count of suggestions waiting for someone, on an app in the
/// sidebar, a language, a page or a tab. Nothing at zero. VoiceOver hears the
/// number from the row it sits on. A 17 pt capsule, 11 pt semibold
/// (README — Design system §5); on Accept All too, the purple part of a blue
/// button.
struct SuggestionBadge: View {
    /// More than this reads "99+".
    nonisolated static let maximumShown = 99

    let count: Int
    var isSmall = false

    var body: some View {
        if count > 0 {
            Text(Self.text(for: count))
                .font((isSmall ? Font.footnote : .subheadline).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(Palette.aiFillLabel)
                .padding(.horizontal, isSmall ? 4 : 5)
                .frame(minWidth: height, minHeight: height)
                .background(Palette.aiFill, in: Capsule())
                .accessibilityHidden(true)
        }
    }

    private var height: CGFloat { isSmall ? 15 : 17 }

    nonisolated static func text(for count: Int) -> String {
        count > maximumShown ? "\(maximumShown)+" : "\(count)"
    }
}

#Preview {
    HStack {
        SuggestionBadge(count: 5)
        SuggestionBadge(count: 32)
        SuggestionBadge(count: 120)
        SuggestionBadge(count: 3, isSmall: true)
    }
    .padding()
}
